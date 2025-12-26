use strict;
use warnings;
use utf8;
use Test::More;
use Test::Command;
use lib 'lib';
use App::optex::Config;
use File::Spec;
use File::Path qw(make_path remove_tree);
use IO::File;

my $lib = File::Spec->rel2abs('lib');
my $bin = File::Spec->rel2abs('script/optex');
my $home = File::Spec->rel2abs('t/home');

sub command {
    Test::Command->new( cmd => [ $^X, "-I$lib", $bin, @_ ]);
}

sub write_file {
    my ($path, $content) = @_;
    my $fh = IO::File->new("> $path") or die "$path: $!";
    print $fh $content;
    $fh->close();
}

$ENV{HOME} = $home;
my $optex_root = $ENV{OPTEX_ROOT} = "${home}/.optex.d";
my $bindir = "${optex_root}/bin";
$ENV{PATH} = "${bindir}:/bin:/usr/bin";

my $config_data = <<'END';
############################################################

no-module = [
	"echo",
]

[alias]
	quadruple = "double 2 *"
	double = "expr 2 *"
	hello = "echo 'hello  world'"

############################################################
END

## make root directory
unless (-d $optex_root) {
    make_path $optex_root or die "${optex_root}: make_path error\n";
}

my $config_file = "${optex_root}/config.toml";
write_file($config_file, $config_data);

my $expr = command('echo', '-M');
is( $expr->stdout_value, "-M\n", 'no-module' );

my $double = command('double', '1');
is( $double->stdout_value, "2\n", 'alias' );

my $hello = command('hello');
is( $hello->stdout_value, "hello  world\n", 'alias string' );


## make bin directory
unless (-d $bindir) {
    make_path $bindir
	or do { warn "mkdir: $!"; goto FINISH };
}

## symlink to perl for '/usr/bin/env perl' to work.
symlink $^X, "${bindir}/perl"
    or do { warn "symlink $^X: $!"; goto FINISH };

## command links
for my $command (qw(echo double quadruple hello)) {
    my $file = "${bindir}/${command}";
    symlink $bin, $file
	or do { warn "symlink $file: $!"; goto FINISH };
}

stdout_is_eq( [ 'echo', '-M' ], "-M\n", 'symlink, no-module' );

stdout_is_eq( [ 'double',  '2' ], "4\n", 'symlink, alias' );

stdout_is_eq( [ 'quadruple',  '2' ], "8\n", 'symlink, alias' );

stdout_is_eq( [ 'hello' ], "hello  world\n", 'symlink, alias string' );

subtest 'config include' => sub {
    my $include_dir = "${optex_root}/config.d";
    make_path $include_dir unless -d $include_dir;

    write_file("$include_dir/10-include.toml", <<'END');
[alias]
inc-one = "echo include one"
inc-two = "echo from include"
END

    my $include_config = <<'END';
include = "~/.optex.d/config.d/*.toml"

[alias]
inc-two = "echo from main"
END

    write_file($config_file, $include_config);

    my $inc_one = command('inc-one');
    is( $inc_one->stdout_value, "include one\n", 'include glob loads alias' );

    my $inc_two = command('inc-two');
    is( $inc_two->stdout_value, "from main\n", 'main config overrides include' );
};

subtest 'include loop detection' => sub {
    my $loop_a = "${optex_root}/loop-a.toml";
    my $loop_b = "${optex_root}/loop-b.toml";

    write_file($loop_a, <<"END");
include = "$loop_b"
[alias]
loop-a = "echo loop a"
END

    write_file($loop_b, <<"END");
include = "$loop_a"
END

    write_file($config_file, <<"END");
include = "$loop_a"
END

    my $loop = command('loop-a');
    $loop->exit_isnt_num(0, 'loop include exits with error');
    like( $loop->stderr_value, qr/include loop detected/, 'loop error message' );
    unlink $loop_a, $loop_b;
};

subtest 'include glob skips self' => sub {
    my $extra = "${optex_root}/extra.toml";
    write_file($extra, <<'END');
[alias]
self-ok = "echo via extra"
END

    write_file($config_file, <<'END');
include = "*.toml"
END

    my $self = command('self-ok');
    is( $self->stdout_value, "via extra\n", 'glob include ignores config.toml itself' );
};

subtest 'missing alias does not recurse' => sub {
    my $noalias = "${bindir}/noalias";
    symlink $bin, $noalias or die "symlink noalias: $!";

    my $none = command('noalias');
    $none->exit_is_num(127, 'command exits with not found status');
    like( $none->stderr_value, qr/command not found/, 'reports missing command' );
    unlink $noalias;
};

subtest 'load_config supports multiple roots' => sub {
    my $a = "${optex_root}/a.toml";
    my $b = "${optex_root}/b.toml";

    write_file($a, <<'END');
[alias]
multi = "echo from a"
END

    write_file($b, <<'END');
[alias]
multi = "echo from b"
extra = "echo extra"
END

    my $cfg = App::optex::Config::load_config($a, $b);
    is($cfg->{alias}{multi},  "echo from b", 'later file overrides earlier');
    is($cfg->{alias}{extra},  "echo extra",  'later file adds keys');
};

done_testing;

FINISH:

## remove entire root directory
File::Path::remove_tree $home or warn "${home}: $!";
