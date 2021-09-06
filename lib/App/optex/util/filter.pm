package App::optex::util::filter;

use v5.10;
use strict;
use warnings;
use Carp;
use utf8;
use Encode;
use open IO => 'utf8', ':std';
use Hash::Util qw(lock_keys);
use Data::Dumper;

my($mod, $argv);

sub initialize {
    ($mod, $argv) = @_;
}

=head1 NAME

util::filter - optex fitler utility module

=head1 SYNOPSIS

B<optex> [ --if/--of I<command> ] I<command>

B<optex> [ --if/--of I<&function> ] I<command>

B<optex> [ --isub/--osub/--psub I<function> ] I<command>

B<optex> I<command> -Mutil::I<filter> [ options ]

=head1 OPTION

=over 4

=item B<--if> I<command>

=item B<--of> I<command>

Set input/output filter command.  If the command start by C<&>, module
function is called instead.

=item B<--pf> I<&function>

Set pre-fork filter function.  This function is called before
executing the target command process, and expected to return text
data, that will be poured into target process's STDIN.  This allows
you to share information between pre-fork and output filter processes.

=item B<--isub> I<function>

=item B<--osub> I<function>

=item B<--psub> I<function>

Set filter function.  These are shortcut for B<--if> B<&>I<function>
and such.

=item B<--set-io-color> IO=I<color>

Set color filter to filehandle.  You can set color filter for STDERR
like this:

    --set-io-color STDERR=R

Use comma to set multiple filehandles at once.

    --set-io-color STDIN=B,STDERR=R

=item B<--io-color>

Set default color to STDOUT and STDERR.

=back

=head1 DESCRIPTION

This module is a collection of sample utility functions for command
B<optex>.

Function can be called with option declaration.  Parameters for the
function are passed by name and value list: I<name>=I<value>.  Value 1
is assigned for the name without value.

In this example,

    optex -Mutil::function(debug,message=hello,count=3)

option I<debug> has value 1, I<message> has string "hello", and
I<count> also has string "3".

=head1 FUNCTION

=over 4

=cut

######################################################################
######################################################################
sub io_filter (&@) {
    my $sub = shift;
    my %opt = @_;
    local @ARGV;
    if ($opt{PREFORK}) {
	my $stdin = $sub->();
	$sub = sub { print $stdin };
	$opt{STDIN} = 1;
    }
    my $pid = do {
	if    ($opt{STDIN})  { open STDIN,  '-|' }
	elsif ($opt{STDOUT}) { open STDOUT, '|-' }
	elsif ($opt{STDERR}) { open STDERR, '|-' }
	else  { croak "Missing option" }
    } // die "fork: $!\n";;
    return $pid if $pid > 0;
    if ($opt{STDERR}) {
	open STDOUT, '>&', \*STDERR or die "dup: $!";
    }
    $sub->();
    close STDOUT;
    close STDERR;
    exit 0;
}

sub set {
    my %opt = @_;
    for my $io (qw(PREFORK STDIN STDOUT STDERR)) {
	my $filter = delete $opt{$io} // next;
	if ($filter =~ s/^&//) {
	    if ($filter !~ /::/) {
		$filter = join '::', __PACKAGE__, $filter;
	    }
	    use Getopt::EX::Func qw(parse_func);
	    my $func = parse_func($filter);
	    io_filter { $func->call() } $io => 1;
	}
	else {
	    io_filter { exec $filter or die "exec: $!\n" } $io => 1;
	}
    }
    %opt and die "Unknown parameter: " . Dumper \%opt;
    ();
}

=item B<set>()

Set input/output filter.

=cut

######################################################################

sub unctrl {
    while (<>) {
	s/([\000-\010\013-\037])/'^' . pack('c', ord($1)|0100)/ge;
	print;
    }
}

=item B<unctrl>()

Visualize control characters.

=cut

######################################################################

my %visible = (
    nul => [ 1, "\000", "\x{2400}", qw(␀ SYMBOL_FOR_NULL)                      ],
    soh => [ 1, "\001", "\x{2401}", qw(␁ SYMBOL_FOR_START_OF_HEADING)          ],
    stx => [ 1, "\002", "\x{2402}", qw(␂ SYMBOL_FOR_START_OF_TEXT)             ],
    etx => [ 1, "\003", "\x{2403}", qw(␃ SYMBOL_FOR_END_OF_TEXT)               ],
    eot => [ 1, "\004", "\x{2404}", qw(␄ SYMBOL_FOR_END_OF_TRANSMISSION)       ],
    enq => [ 1, "\005", "\x{2405}", qw(␅ SYMBOL_FOR_ENQUIRY)                   ],
    ack => [ 1, "\006", "\x{2406}", qw(␆ SYMBOL_FOR_ACKNOWLEDGE)               ],
    bel => [ 1, "\007", "\x{2407}", qw(␇ SYMBOL_FOR_BELL)                      ],
    bs  => [ 1, "\010", "\x{2408}", qw(␈ SYMBOL_FOR_BACKSPACE)                 ],
    ht  => [ 1, "\011", "\x{2409}", qw(␉ SYMBOL_FOR_HORIZONTAL_TABULATION)     ],
    nl  => [ 1, "\012", "\x{240A}", qw(␊ SYMBOL_FOR_LINE_FEED)                 ],
    vt  => [ 1, "\013", "\x{240B}", qw(␋ SYMBOL_FOR_VERTICAL_TABULATION)       ],
    np  => [ 1, "\014", "\x{240C}", qw(␌ SYMBOL_FOR_FORM_FEED)                 ],
    cr  => [ 1, "\015", "\x{240D}", qw(␍ SYMBOL_FOR_CARRIAGE_RETURN)           ],
    so  => [ 1, "\016", "\x{240E}", qw(␎ SYMBOL_FOR_SHIFT_OUT)                 ],
    si  => [ 1, "\017", "\x{240F}", qw(␏ SYMBOL_FOR_SHIFT_IN)                  ],
    dle => [ 1, "\020", "\x{2410}", qw(␐ SYMBOL_FOR_DATA_LINK_ESCAPE)          ],
    dc1 => [ 1, "\021", "\x{2411}", qw(␑ SYMBOL_FOR_DEVICE_CONTROL_ONE)        ],
    dc2 => [ 1, "\022", "\x{2412}", qw(␒ SYMBOL_FOR_DEVICE_CONTROL_TWO)        ],
    dc3 => [ 1, "\023", "\x{2413}", qw(␓ SYMBOL_FOR_DEVICE_CONTROL_THREE)      ],
    dc4 => [ 1, "\024", "\x{2414}", qw(␔ SYMBOL_FOR_DEVICE_CONTROL_FOUR)       ],
    nak => [ 1, "\025", "\x{2415}", qw(␕ SYMBOL_FOR_NEGATIVE_ACKNOWLEDGE)      ],
    syn => [ 1, "\026", "\x{2416}", qw(␖ SYMBOL_FOR_SYNCHRONOUS_IDLE)          ],
    etb => [ 1, "\027", "\x{2417}", qw(␗ SYMBOL_FOR_END_OF_TRANSMISSION_BLOCK) ],
    can => [ 1, "\030", "\x{2418}", qw(␘ SYMBOL_FOR_CANCEL)                    ],
    em  => [ 1, "\031", "\x{2419}", qw(␙ SYMBOL_FOR_END_OF_MEDIUM)             ],
    sub => [ 1, "\032", "\x{241A}", qw(␚ SYMBOL_FOR_SUBSTITUTE)                ],
    esc => [ 0, "\033", "\x{241B}", qw(␛ SYMBOL_FOR_ESCAPE)                    ],
    fs  => [ 1, "\034", "\x{241C}", qw(␜ SYMBOL_FOR_FILE_SEPARATOR)            ],
    gs  => [ 1, "\035", "\x{241D}", qw(␝ SYMBOL_FOR_GROUP_SEPARATOR)           ],
    rs  => [ 1, "\036", "\x{241E}", qw(␞ SYMBOL_FOR_RECORD_SEPARATOR)          ],
    us  => [ 1, "\037", "\x{241F}", qw(␟ SYMBOL_FOR_UNIT_SEPARATOR)            ],
    sp  => [ 1, "\040", "\x{2420}", qw(␠ SYMBOL_FOR_SPACE)                     ],
    del => [ 1, "\177", "\x{2421}", qw(␡ SYMBOL_FOR_DELETE)                    ],
);

use List::Util qw(pairmap);
my %v = pairmap { $b->[1] => $b->[2] } %visible;

my $keep_after = qr/[\n]/;

use Text::ANSI::Tabs qw(ansi_expand);

sub visible {
    my %vchar = map { $_ => $visible{$_}->[0] } keys %visible;
    lock_keys %vchar;
    pairmap {
	map { $vchar{$_} = $b } $a eq 'all' ? keys %visible : $a;
    } @_;
    my @vchar = grep { $vchar{$_} } keys %vchar;
    my $vchar = join '', map { $visible{$_}->[1] } @vchar;
    while (<>) {
	$_ = ansi_expand($_, tabstyle => 'bar');
	s/(?=(${keep_after}?))([$vchar]|(?!))/$v{$2}$1/g
	    if $vchar ne '';           #^^^^ does not work w/o this. bug?
	print;
    }
}

=item B<visible>()

Make control characters visible.

=cut

######################################################################

sub rev_line {
    print reverse <STDIN>;
}

=item B<rev_line>()

Reverse output.

=cut

######################################################################

sub rev_char {
    while (<>) {
	print reverse /./g;
	print "\n" if /\n\z/;
    }
}

=item B<rev_char>()

Reverse characters in each line.

=cut

######################################################################

use List::Util qw(shuffle);

sub shuffle_line {
    print shuffle <>;
}

=item B<shuffle_line>()

Shuffle lines.

=cut

######################################################################

use Getopt::EX::Colormap qw(colorize);

sub io_color {
    my %opt = @_;
    for my $io (qw(STDIN STDOUT STDERR)) {
	my $color = $opt{$io} // next;
	io_filter {
	    while (<>) {
		print colorize($color, $_);
	    }
	} $io => 1;
    }
    ();
}

=item B<io_color>( B<IO>=I<color> )

Colorize text. B<IO> is either of C<STDOUT> or C<STDERR>.  Use comma
to set both at a same time: C<STDOUT=C,STDERR=R>.

=cut

######################################################################

sub splice_line {
    my %opt = @_;
    my @line = <>;
    if (my $length = $opt{length}) {
	print splice @line, $opt{offset} // 0, $opt{length};
    } else {
	print splice @line, $opt{offset} // 0;
    }
}

=item B<splice_line>( offset=I<n>, [ length=I<m> ] )

Splice lines.

=cut

######################################################################

use Time::Piece;
use Getopt::EX::Colormap qw(colorize);

sub timestamp {
    my %opt = @_;
    my $format = $opt{format} || "%T.%f";
    my $color = $opt{color} || 'Y';

    my $sub = do {
	my $re_subsec = qr/%f|(?<milli>%L)|%(?<prec>\d*)N/;
	if ($format =~ /$re_subsec/) {
	    require Time::HiRes;
	    my $prec = $+{milli} ? 3 : $+{prec} || 6;
	    sub {
		my($sec, $usec) = Time::HiRes::gettimeofday();
		$usec /= (10 ** (6 - $prec)) if 0 < $prec and $prec < 6;
		(my $time = $format)
		    =~ s/$re_subsec/sprintf("%0${prec}d", $usec)/ge;
		localtime($sec)->strftime($time);
	    }
	} else {
	    sub {
		localtime(time)->strftime($format);
	    }
	}
    };

    while (<>) {
	print colorize($color, $sub->()), " ", $_;
    }
}

=item B<timestamp>( [ format=I<strftime_format> ] )

Put timestamp on each line of output.

Format is interpreted by C<strftime> function.  Default format is
C<"%T.%f"> where C<%T> is 24h style time C<%H:%M:%S>, and C<%f> is
microsecond.  C<%L> means millisecond. C<%nN> can be used to specify
precision.

=cut

######################################################################

sub gunzip { exec "gunzip -c" }

sub gzip   { exec "gzip -c" }

=item B<gunzip>()

Gunzip standard input.

=item B<gzip>()

Gzip standard input.

=cut

######################################################################
######################################################################

=back

=head1 EXAMPLE

    optex -Mutil::filter --osub timestamp ping -c 10 localhost

=head1 SEE ALSO

L<App::optex::xform>

L<https://qiita.com/kaz-utashiro/items/2df8c7fbd2fcb880cee6>

=cut

1;

__DATA__

mode function

option --if &set(STDIN=$<shift>)
option --of &set(STDOUT=$<shift>)
option --ef &set(STDERR=$<shift>)
option --pf &set(PREFORK=$<shift>)

option --isub &set(STDIN=&$<shift>)
option --osub &set(STDOUT=&$<shift>)
option --esub &set(STDERR=&$<shift>)
option --psub &set(PREFORK=&$<shift>)

option --set-io-color &io_color($<shift>)
option --io-color --set-io-color STDERR=555/201;E
