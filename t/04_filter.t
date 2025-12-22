use strict;
use warnings;
use utf8;
use Test::More;
use File::Spec;
use File::Temp qw(tempfile);

my $t = File::Spec->rel2abs('t');
my $lib = File::Spec->rel2abs('lib');
my $bin = File::Spec->rel2abs('script/optex');

$ENV{HOME} = "$t/home";
$ENV{PATH} = "/bin:/usr/bin";

# Helper to run optex and capture output
sub optex_out {
    my @args = @_;
    open my $fh, '-|', $^X, "-I$lib", $bin, @args
        or die "Cannot run optex: $!";
    my $out = do { local $/; <$fh> };
    close $fh;
    return $out // '';
}

# Helper to run optex and capture stdout+stderr
sub optex_out_err {
    my @args = @_;
    my $pid = open my $fh, '-|';
    die "fork: $!" unless defined $pid;
    if ($pid == 0) {
        open STDERR, '>&', \*STDOUT;
        exec $^X, "-I$lib", $bin, @args;
        die "exec: $!";
    }
    my $out = do { local $/; <$fh> };
    close $fh;
    return $out // '';
}

# Test --of (basic filter)
{
    my $out = optex_out('-Mutil::filter', '--of', 'cat -n', 'echo', 'hello');
    like($out, qr/1\s+hello/, '--of cat -n');
}

# Test --yf (merged stdout+stderr)
{
    my $out = optex_out_err('-Mutil::filter', '--yf', 'cat -n',
                            'perl', '-e', 'print "out\n"; warn "err\n"');
    like($out, qr/\d\s+err/, '--yf: stderr has line number');
    like($out, qr/\d\s+out/, '--yf: stdout has line number');
}

# Test --ef '>&1' (dup stderr to stdout)
{
    my $out = optex_out_err('-Mutil::filter', '--of', 'cat -n', '--ef', '>&1',
                            'perl', '-e', 'print "out\n"; warn "err\n"');
    like($out, qr/\d\s+err/, '--ef >&1: stderr has line number');
    like($out, qr/\d\s+out/, '--ef >&1: stdout has line number');
}

# Test --ef '*STDOUT' (dup stderr to stdout, Perl style)
{
    my $out = optex_out_err('-Mutil::filter', '--of', 'cat -n', '--ef', '*STDOUT',
                            'perl', '-e', 'print "out\n"; warn "err\n"');
    like($out, qr/\d\s+err/, '--ef *STDOUT: stderr has line number');
    like($out, qr/\d\s+out/, '--ef *STDOUT: stdout has line number');
}

# Test >file redirect
{
    my ($fh, $tmpfile) = tempfile(UNLINK => 1);
    close $fh;
    my $out = optex_out('-Mutil::filter', '--ef', ">$tmpfile",
                        'perl', '-e', 'print "out\n"; warn "err\n"');
    is($out, "out\n", '>file: stdout not redirected');
    open my $in, '<', $tmpfile or die;
    my $content = do { local $/; <$in> };
    close $in;
    like($content, qr/err/, '>file: stderr saved to file');
}

# Test >>file append redirect
{
    my ($fh, $tmpfile) = tempfile(UNLINK => 1);
    print $fh "first\n";
    close $fh;
    optex_out('-Mutil::filter', '--ef', ">>$tmpfile",
              'perl', '-e', 'warn "second\n"');
    open my $in, '<', $tmpfile or die;
    my $content = do { local $/; <$in> };
    close $in;
    like($content, qr/first/, '>>file: original content preserved');
    like($content, qr/second/, '>>file: new content appended');
}

# Test --ysub (merged with function)
{
    my $out = optex_out_err('-Mutil::filter', '--ysub', 'visible',
                            'perl', '-e', 'print "out\n"; warn "err\n"');
    like($out, qr/out/, '--ysub: stdout processed');
    like($out, qr/err/, '--ysub: stderr processed');
}

done_testing;
