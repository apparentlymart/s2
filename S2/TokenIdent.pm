#!/usr/bin/perl
#

package S2::TokenIdent;

use strict;
use S2::Token;
use S2::TokenKeyword;
use vars qw($VERSION @ISA $DEFAULT $TYPE $STRING);

$VERSION = '1.0';
@ISA = qw(S2::Token);

# numeric values for $this->{'type'}
$DEFAULT = 0;
$TYPE    = 1;
$STRING  = 2;

sub new 
{
    my ($class, $ident) = @_;
    my $kwtok = S2::TokenKeyword->tokenFromString($ident);
    return $kwtok if $kwtok;
    bless {
        'chars' => $ident,
    }, $class;
}

sub getIdent {
    shift->{'chars'};
}

sub toString {
    my $this = shift;
    "[TokenIdent] = $this->{'chars'}";
}

sub setType {
    my ($this, $type) = @_;
    $this->{'type'} = $type;
}

1;

