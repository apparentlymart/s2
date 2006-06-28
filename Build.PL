#!/usr/bin/perl
#
#   Compiles S2::Parrot::Embedded.
#

use strict;
use warnings FATAL => 'all';
use ExtUtils::Embed;

my $LIBPATH = 'CoreEmbedded.so';
my $LDFLAGS = '';
if ($^O eq 'darwin') {
    $LIBPATH = 'CoreEmbedded.bundle';
    $LDFLAGS = '-bundle /usr/lib/bundle1.o';
    $ENV{'MACOSX_DEPLOYMENT_TARGET'} = '10.3';
}

my $op = $ARGV[0] || 'build';

if ($op eq 'build') {
    print STDERR "First, I'll make sure you have all the prerequisites.\n";
    print STDERR "Checking for pkg-config... ";
    if (system 'pkg-config --version') {
        print STDERR <<'HERE';
I'll need pkg-config to figure out how to compile and link with Parrot. You
can get pkg-config from http://pkgconfig.freedesktop.org/releases/.

HERE
        exit;
    }

    print STDERR "Checking for Parrot... ";
    if (system 'parrot -V') {
        print STDERR <<'HERE';
I'll need a working copy of Parrot to link to. You can get it from
http://www.parrotcode.org/.

HERE
        exit;
    }
    print STDERR "okay.\nChecking for SWIG... ";
    if (system 'swig -version') {
        print STDERR <<'HERE';
I'll need SWIG to embed Parrot into the Perl S2 core. You can get SWIG from
http://www.swig.org/.

HERE
        exit;
    }
    print STDERR "okay.\nLooks good.\n";

    print STDERR "Compiling S2::Parrot::Embedded...\n";

    chdir 'S2/Parrot';

    my $cmd = 'swig -perl5 CoreEmbedded.i';
    print STDERR $cmd . "\n";
    system $cmd and die "Failed to run SWIG.\n";

    $cmd = 'gcc -Wall -c CoreEmbedded_wrap.c' . ccopts() . ' ' .
        `pkg-config --cflags parrot`;
    $cmd =~ s/[\r\n]/ /g;
    print STDERR $cmd . "\n";
    system $cmd and die "Failed to compile.\n";

    $cmd = 'ld ' . $LDFLAGS . ' CoreEmbedded_wrap.o' . ldopts() . ' ' .
        `pkg-config --libs parrot` . ' -o ' . $LIBPATH;
    $cmd =~ s/[\r\n]/ /g;
    print STDERR $cmd . "\n"; 
    system $cmd and die "Failed to link.\n";

    $cmd = "mv $LIBPATH ../../$LIBPATH";
    print STDERR $cmd . "\n";
    system $cmd;

    print STDERR "All done.\n";
} elsif ($op eq 'clean') {
    unlink 'S2/Parrot/CoreEmbedded.pm';
    unlink 'S2/Parrot/CoreEmbedded_wrap.c';
    unlink 'S2/Parrot/CoreEmbedded_wrap.o';
    unlink "./$LIBPATH";
    unlink './CoreEmbedded.bundle';
}

