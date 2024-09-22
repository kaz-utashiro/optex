use strict;
use warnings;
use utf8;
use Test::More;
use File::Spec;

my $t = File::Spec->rel2abs('t');
my $lib = File::Spec->rel2abs('lib');
my $bin = File::Spec->rel2abs('script/optex');


$ENV{HOME} = "$t/home";

is(optex(), 2);

$ENV{PATH} = "/bin:/usr/bin";
is(optex('true'),  0, 'true');
isnt(optex('false'), 0, 'false');

is(optex('-Mhelp', 'true'),  0, '-Mhelp');
is(optex('-MApp::optex::help', 'true'),  0, '-MApp::optex::help');
is(optex('-Mdebug', 'true'),  0, '-Mdebug');
is(optex('-Mutil', 'true'),  0, '-Mutil');
TODO: {
    local $TODO = 'LOAD ERROR -Mutil::filter';
    is(optex('-Mutil::filter', 'true'),  0, '-Mutil::filter');
}
is(optex('-Mutil::argv', 'true'),  0, '-Mutil::argv');

isnt(optex('false'),  0, 'false');
is(optex('--exit=0', 'false'),  0, '--exit=0');
is(optex('--exit=2', 'true'),  2, '--exit=2');

done_testing;

sub optex {
    system($^X, "-I$lib", $bin, @_) >> 8;
}
