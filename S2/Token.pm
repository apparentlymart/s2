#!/usr/bin/perl
#

package S2::Token;

use strict;

sub getFilePos {
    my $this = shift;
    return $this->{'pos'};
}

sub isNecessary {
    my $this = shift;
    return 1;
}

sub toString {
    die "Abstract! " . Data::Dumper::Dumper(@_);
}

sub asHTML {
    die "Abstract";
}

sub asS2 {
    my ($this, $o) = @_; # Indenter o
    $o->write("##Token::asS2##");
}

sub asPerl {
    my ($this, $bp, $o) = @_; # BackendPerl bp, Indenter o
    $o->write("##Token::asPerl##");
}




1;
