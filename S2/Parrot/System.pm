#!/usr/bin/perl
#
#   Interface to S2 running on Parrot. This class aims to be compatible as a
#   "drop-in replacement" for the generic S2 class and implements the same
#   interface as the "S2" class to the best degree we can.
#

package S2;

require 5.008_000;

use strict;
use warnings FATAL => 'all';
use Carp;
use Data::Dumper qw/Dumper/;
use S2::Parrot::Embedded;

no warnings 'redefine';

#
#   Function mangling is done in a method similar to that of GCC 3.x. The
#   signature is expected to be in standard S2 format; e.g.
#   foo(int,string,RecentPage). 
#
sub mangle
{
    my ($signature) = @_;

    my $mangled = '_Z';

    $signature =~ /^(\w+)\(([^)]*)\)$/ or croak
        "Malformed signature: $signature";
    my ($name, $args) = ($1, $2);
    
    foreach my $arg (split /,/, $args) {
        $arg =~ /^(\w+)(\W*)$/;
        my ($base_name, $array_qualifiers) = ($1, $2);

        $mangled .= 'A' . length($base_name) . $base_name;

        $array_qualifiers =~ s/\[\]/a/g;
        $array_qualifiers =~ s/\{\}/h/g;
        $mangled .= 'Q' . length($array_qualifiers) . $array_qualifiers if
            length $array_qualifiers;
    }

    $mangled .= 'E' . $name;

    return $mangled;
}

sub run_code
{
    my ($context, $signature) = @_;

    # FIXME
    S2::Parrot::Embedded->run_parrot_function('_ZEmain');
}

sub check_defined
{
    my ($object) = @_;

    return defined $object;
}

1;

package S2::Parrot::System;

1;

