package App::optex::util::argv;

use v5.10;
use strict;
use warnings;
use utf8;
use Encode;
use Data::Dumper;

my($mod, $argv);
sub initialize { ($mod, $argv) = @_ }

binmode STDIN,  ":encoding(utf8)";
binmode STDOUT, ":encoding(utf8)";

sub argv (&) {
    my $sub = shift;
    @$argv = $sub->(@$argv);
}

my %options = (
    "move"   => "\$<move(\$<shift>)>",
    "remove" => "\$<remove(\$<shift>)>",
    "copy"   => "\$<copy(\$<shift>)>",
    "exch"   => "\$<move(1,1)>",
    "times"     => "-M__PACKAGE__::times(count=\$<shift>) \$<move>",
    "reverse"   => "-M__PACKAGE__::reverse() \$<move>",
    "collect"   => "-M__PACKAGE__::collect(\$<shift>) \$<move>",
    "index"     => "-M__PACKAGE__::collect(index=\$<shift>) \$<move>",
    "glob"      => "-M__PACKAGE__::collect(glob=\$<shift>) \$<move>",
    "omit"      => "-M__PACKAGE__::collect(omit=\$<shift>) \$<move>",
    "match"     => "-M__PACKAGE__::collect(match=\$<shift>) \$<move>",
    "unmatch"   => "-M__PACKAGE__::collect(unmatch=\$<shift>) \$<move>",
    "include"   => "-M__PACKAGE__::collect(match=\$<shift>) \$<move>",
    "exclude"   => "-M__PACKAGE__::collect(unmatch=\$<shift>) \$<move>",
    "filter"    => "-M__PACKAGE__::filter(command=\$<shift>) \$<move>",
    );

sub enable {
    my %opt = @_;
    if ($opt{':all'}) {
	map { $opt{$_} //= 1 } keys %options;
    }
    for my $name (keys %opt) {
	my $value = $options{$name} or next;
	if ($opt{$name} ne "1") {
	    $name = $opt{$name};
	}
	$mod->setopt("--$name", $value);
    }
}

=head1 NAME

util::argv - optex argument utility modules

=head1 SYNOPSIS

optex command -Mutil::argv

=head1 DESCRIPTION

This module is a collection of sample utility functions for command
B<optex>.

Function can be called with option declaration.  Parameters for the
function are passed by name and value list: I<name>=I<value>.  Value 1
is assigned for the name without value.

In this example,

    optex -Mutil::argv::function(debug,message=hello,count=3)

option B<debug> has value 1, B<message> has string "hello", and
B<count> also has string "3".

The above command can also be written as follows.

    optex -Mutil::argv::function=debug,message=hello,count=3

The upper format is easier to read visually, but the lower format is
easier to type from the keyboard.

=head1 FUNCTION

=over 4

=cut

######################################################################
######################################################################

sub times {
    my %opt = @_;
    my $count  = $opt{count}  // 2;
    my $suffix = $opt{suffix} // '';
    my $prefix = $opt{prefix} // '';
    argv {
	map {
	    ( $_, ($prefix.$_.$suffix) x ($count - 1) );
	} @_;
    }
}

=item B<times>(B<count>=I<n>,B<suffix>=I<str>)

Multiply each arguments.  Default B<count> is 2.

    % optex echo -Mutil::argv::times(count=3) 1 2 3
    1 1 1 2 2 2 3 3 3

Put B<suffix> to duplicated arguments.

    % optex echo -Mutil::argv::times(suffix=.bak) a b c
    a a.bak b b.bak c c.bak

=cut

######################################################################

sub reverse {
    argv { reverse @_ };
}

=item B<reverse>()

Reverse arguments.

=cut

######################################################################

use Text::Glob qw(glob_to_regex);
use File::Basename qw(basename);

sub collect {
    my %opt = @_;
    $opt{match}   //= $opt{include};
    $opt{unmatch} //= $opt{exclude};
    if ($opt{index}) {
	my @index = $opt{index} =~ /\d+/g;
	argv {
	    @_[ grep { $_ <= $#_ } map { $_ - 1 } @index ];
	}
    }
    elsif (my $glob = $opt{glob} || $opt{omit}) {
	my $re = glob_to_regex($glob);
	argv {
	    if ($opt{glob}) {
		grep { basename($_) =~ /$re/ } @_;
	    } else {
		grep { basename($_) !~ /$re/ } @_;
	    }
	}
    }
    elsif (my $re = $opt{match} || $opt{unmatch}) {
	argv {
	    if ($opt{match}) {
		grep {  /$re/ } @_;
	    } else {
		grep { !/$re/ } @_;
	    }
	}
    }
    else {
	die "collect: no valid parameter.\n";
    }
}

=item B<collect>(index=2:4:6)

=item B<collect>(glob=*.c)

=item B<collect>(omit=*.c)

=item B<collect>(match=.c$)

=item B<collect>(unmatch=.c$)

Collect arguments based on the given parameter.

=over 4

=item B<index>=I<index>

    % optex echo -Mutil::argv::collect=index=2:4:6 one two three four five six

will print:

    two four six

=item B<glob>=I<wildcard>

=item B<omit>=I<wildcard>

    % optex ls -Mutil::argv::collect=glob=*.c foo.h foo.c foo.1

will print:

    foo.c

B<omit> is reverse of B<glob>.

=item B<match>=I<regex>

    % optex ls -Mutil::argv::collect=match=.c$ foo.h foo.c foo.1

will print:

    foo.c

=item B<unmatch>=I<regex>

    % optex ls -Mutil::argv::collect=unmatch=.c$ foo.h foo.c foo.1

will print:

    foo.h foo.1

=back

=cut

######################################################################

use App::optex::Tmpfile;

sub proc {
    state @persist;
    argv {
	for (@_) {
	    my($command) = /^ \<\( (.*) \) $/x or next;
	    my $tmp = new App::optex::Tmpfile;
	    $tmp->write(`$command`)->rewind;
	    push @persist, $tmp;
	    $_ = $tmp->path;
	}
	@_;
    }
}

=item B<proc>()

Process substitution.

    % optex diff -Mutil::argv::proc= '<(date)' '<(date -u)'

=cut

######################################################################

use App::optex::Tmpfile;

sub filter {
    state @persist;
    my %arg = @_;
    my $command = $arg{command} or die "command parameter is required.\n";
    argv {
	for (@_) {
	    -e $_ or next;
	    my $tmp = new App::optex::Tmpfile;
	    $tmp->write(`$command < $_`)->rewind;
	    push @persist, $tmp;
	    $_ = $tmp->path;
	}
	@_;
    }
}

=item B<filter>(B<command>=I<command>)

Execute filter command for each file.  Specify any command which
should be invoked for each argument.

    % optex diff -Mutil::argv::filter=command='cat -n' foo bar

In this example, C<foo> and C<bar> are replaced by the result output
of C<< cat -n < foo >> and C<< cat -n < bar >>. The replacement only
occurs when the file corresponding to the argument exists.

=cut

######################################################################

=back

=head1 OPTIONS

Several options are prepared and enabled by request.  To enable
specific option, use B<enable> function like this to enable B<--move>
and B<--copy> options.

    -Mutil::argv::enable=move,copy

Parameter B<:all> can be used to enable everything.

    -Mutil::argv::enable=:all

You can use alternative names:

    -Mutil::argv::enable(move=mymove,copy=mycopy)

=over 4

=item B<--move>   I<param>

=item B<--remove> I<param>

=item B<--copy>   I<param>

These options are converted C<< $<command(param)> >> notation, where
I<param> is B<offset> or B<offset>,B<length>.

B<--move 0> moves all following arguments there, B<--remove 0> just
removes them, and B<--copy 0> copies them.

B<--move 0,1> moves following argument (which does not change
anything), and B<--move 1,1> moves second argument (exchange following
two).

B<--move -1> moves the last argument.

B<--copy 0,1> duplicates the next.

=item B<--exch>

Exchanges following two arguments.  This is same as B<--move 1,1>.

    optex -Mutil::argv::enable=exch echo --exch foo bar

will print:

    bar foo

=item B<--filter> I<command>

Set input filter for each file argument.

Next command passes the result of the C<expand> filter to the C<cat
-n> for each file in the command line.

    optex -Mutil::argv::enable=filter cat -n --filter=expand a b c

=back

Following options are interface for builtin functions.

=over 4

=item B<--times> I<count>

=item B<--reverse>

=item B<--index> I<index>

=item B<--glob> I<wildcard>

=item B<--omit> I<wildcard>

=item B<--match> I<regex>

=item B<--unmatch> I<regex>

=back

=cut

1;

__DATA__
