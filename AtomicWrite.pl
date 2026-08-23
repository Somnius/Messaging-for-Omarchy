#!/usr/bin/perl

use strict;
use warnings;

use Encode qw(FB_CROAK decode);
use File::Basename qw(basename dirname);
use File::Temp qw(tempfile);
use IO::Handle;

my $temporary_path;

sub fail {
  my ($code, $message) = @_;
  unlink($temporary_path) if defined($temporary_path);
  print STDERR "$message\n";
  exit $code;
}

@ARGV == 3 or fail(64, "usage: AtomicWrite.pl PATH MAX_BYTES DATA");
my ($path, $max_bytes, $data) = @ARGV;
$max_bytes =~ /\A[1-9][0-9]*\z/ && $max_bytes <= 1_048_576
  or fail(64, "invalid byte limit");
length($data) <= $max_bytes or fail(5, "output exceeds byte limit");
my $utf8_check = $data;
eval { decode("UTF-8", $utf8_check, FB_CROAK); 1 }
  or fail(7, "output is not valid UTF-8");

my $directory = dirname($path);
my $name = basename($path);
my ($file, $created_path);
eval {
  ($file, $created_path) = tempfile(".$name.tmp.XXXXXXXX",
    DIR => $directory, UNLINK => 0);
  1;
} or fail(3, "temporary output open failed");
$temporary_path = $created_path;
binmode($file, ":raw") or fail(4, "temporary output setup failed");

my $offset = 0;
while ($offset < length($data)) {
  my $written = syswrite($file, $data, length($data) - $offset, $offset);
  defined($written) && $written > 0 or fail(4, "temporary output write failed");
  $offset += $written;
}
$file->sync or fail(4, "temporary output sync failed");
close($file) or fail(4, "temporary output close failed");
rename($temporary_path, $path) or fail(6, "atomic output rename failed");
$temporary_path = undef;
