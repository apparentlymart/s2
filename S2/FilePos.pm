#!/usr/bin/perl
#

package S2::FilePos;

use strict;

sub new
{
    my ($class, $l, $c) = @_;
    my $this = {
        'line' => $l,
        'col' => $c,
    };
    bless $this, $class;
    return $this;
}

sub clone
{
    my $this = shift;
    return new S2::FilePos($this->{'line'}, $this->{'col'});
}

sub locationString
{
    my $this = shift;
    return "line $this->{'line'}, column $this->{'col'}";
}

sub toString
{
    my $this = shift;
    return $this->locationString();
}

1;
