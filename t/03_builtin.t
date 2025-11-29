use strict;
use warnings;
use Test::More;
use File::Spec;

my $lib = File::Spec->rel2abs('lib');
my $bin = File::Spec->rel2abs('script/optex');

# Create test module
my $test_module = 't/testbuiltin.pm';
open my $fh, '>', $test_module or die "$test_module: $!";
print $fh <<'END';
package testbuiltin;

use v5.14;
use warnings;

our $flag;
our $value;

END {
    warn "flag=", ($flag // "undef"), "\n";
    warn "value=", ($value // "undef"), "\n";
}

1;

__DATA__

builtin flag      $flag
builtin value=i   $value
END
close $fh;

# Test builtin options
subtest 'builtin flag' => sub {
    my $out = `$^X -It -I$lib $bin -Mtestbuiltin --flag true 2>&1`;
    like($out, qr/flag=1/, 'flag is set to 1');
};

subtest 'builtin value' => sub {
    my $out = `$^X -It -I$lib $bin -Mtestbuiltin --value=42 true 2>&1`;
    like($out, qr/value=42/, 'value is set to 42');
};

subtest 'builtin both' => sub {
    my $out = `$^X -It -I$lib $bin -Mtestbuiltin --flag --value=99 true 2>&1`;
    like($out, qr/flag=1/, 'flag is set');
    like($out, qr/value=99/, 'value is set');
};

subtest 'builtin not set' => sub {
    my $out = `$^X -It -I$lib $bin -Mtestbuiltin true 2>&1`;
    like($out, qr/flag=undef/, 'flag is undef');
    like($out, qr/value=undef/, 'value is undef');
};

# Cleanup
unlink $test_module;

done_testing;
