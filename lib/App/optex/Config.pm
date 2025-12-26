package App::optex::Config;
use strict;
use warnings;
use TOML ();
use File::Glob qw(bsd_glob);
use File::Spec;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use Scalar::Util qw(reftype);

# load_config($path, ...)
sub load_config {
    my (@files) = @_;
    die "load_config requires file\n" unless @files;

    my $merged = {};
    for my $file (@files) {
        die "load_config requires file\n" unless defined $file && length $file;

        my $path = _maybe_config_path($file);
        next unless $path;

        my %seen;
        my $config = _load_with_include($path, \%seen, 0);
        $merged = _merge($merged, $config);
    }
    return $merged;
}

sub _load_with_include {
    my ($file, $seen, $depth) = @_;
    die "include depth too deep ($depth)\n" if $depth > 20;

    my $path = _normalize_path($file);
    die "config not found: $file\n" unless defined $path && -f $path;

    if ($seen->{$path}) {
        die "include loop detected: $path\n";
    }
    $seen->{$path} = 1;

    my $base = _toml_load($path) || {};

    my $inc    = delete $base->{include};
    my $merged = {};

    if ($inc) {
        my @files = _expand_include($inc, dirname($path));
        for my $f (@files) {
            my $child_path = _normalize_path($f);
            next if !defined $child_path || $child_path eq $path;  # skip self include
            my $child = _load_with_include($child_path, $seen, $depth + 1);
            $merged = _merge($merged, $child);
        }
    }
    $merged = _merge($merged, $base);
    delete $seen->{$path};
    return $merged;
}

sub _toml_load {
    my ($path) = @_;
    my $txt = _slurp($path);
    my ($data, $err) = TOML::from_toml($txt);
    die "$path: $err\n" unless $data;
    return $data;
}

sub _slurp {
    my ($path) = @_;
    open my $fh, '<:encoding(UTF-8)', $path or die "open $path: $!";
    local $/;
    my $txt = <$fh>;
    close $fh;
    return $txt;
}

sub _expand_include {
    my ($inc, $base_dir) = @_;
    my @items;
    my $t = reftype($inc) || '';

    if (!$t) {
        @items = ($inc);
    }
    elsif ($t eq 'ARRAY') {
        @items = @$inc;
    }
    else {
        die "include must be string or array\n";
    }

    my @files;
    for my $item (@items) {
        next unless defined $item && length $item;
        $item = _expand_tilde($item);
        if ($base_dir && !File::Spec->file_name_is_absolute($item)) {
            $item = File::Spec->rel2abs($item, $base_dir);
        }

        my @g = bsd_glob($item, File::Glob::GLOB_TILDE | File::Glob::GLOB_NOSORT);
        if (@g) {
            push @files, sort @g;
        }
        else {
            push @files, $item;
        }
    }
    return @files;
}

sub _expand_tilde {
    my ($path) = @_;
    return $path unless $path =~ /^~/;
    my $home = $ENV{HOME} || (getpwuid($<))[7] || '';
    $path =~ s/^~/$home/;
    return $path;
}

sub _normalize_path {
    my ($path) = @_;
    $path = _expand_tilde($path);
    my $abs = File::Spec->file_name_is_absolute($path)
        ? $path
        : File::Spec->rel2abs($path);
    return abs_path($abs) || $abs;
}

sub _maybe_config_path {
    my ($path) = @_;
    my $norm = _normalize_path($path);
    return unless defined $norm && -f $norm;
    return $norm;
}

sub _merge {
    my ($a, $b) = @_;
    $a ||= {};
    $b ||= {};
    my %out = %$a;

    for my $k (keys %$b) {
        my $va = $out{$k};
        my $vb = $b->{$k};
        my $ta = reftype($va) || '';
        my $tb = reftype($vb) || '';

        if ($ta eq 'HASH' && $tb eq 'HASH') {
            $out{$k} = _merge($va, $vb);
        }
        elsif ($ta eq 'ARRAY' && $tb eq 'ARRAY') {
            $out{$k} = [ @$va, @$vb ];
        }
        else {
            $out{$k} = $vb;
        }
    }
    return \%out;
}

1;

=pod

=encoding utf8

=head1 NAME

App::optex::Config - load optex config with recursive include support

=head1 SYNOPSIS

  use App::optex::Config;

  my $config = App::optex::Config::load_config("$ENV{HOME}/.optex.d/config.toml");

=head1 FUNCTIONS

=head2 load_config

  my $config = App::optex::Config::load_config($path, ...);

Loads a TOML config file and expands any top-level C<include> directives.
Returns a hashref of the merged configuration.

=head1 DESCRIPTION

=cut

