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
    bless {
        'ident' => $ident,
    }, $class;
}

sub getIdent 
{
    my $this = shift;
    $this->{'ident'};
}

sub toString
{
    my $this = shift;
    "[TokenIdent] = $this->{'ident'}";
}

sub setType
{
    my ($this, $type) = @_;
    $this->{'type'} = $type;
}

sub canStart
{
    my ($class, $t) = @_;
    my $nextchar = $t->peekChar();
    return $nextchar =~ /[a-zA-Z_]/;
}

sub scan
{
    my ($class, $t) = @_;
    my $tbuf;
    while ($t->peekChar() =~ /[a-zA-Z0-9_]/) {
        $tbuf .= $t->getChar();
    }
    my $kwtok = S2::TokenKeyword->tokenFromString($tbuf);
    return $kwtok || new S2::TokenIdent($tbuf);
}
1;

