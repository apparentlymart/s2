#!/usr/bin/perl
#

package S2::TokenWhitespace;

use strict;
use S2::Token;
use vars qw($VERSION @ISA);

$VERSION = '1.0';
@ISA = qw(S2::Token);

sub new {
    my ($class, $ws) = @_;
    my $this = {
        'ws' => $ws,
    };
    bless $this, $class;
}

sub isNecessary { 0; }

sub getWhiteSpace { 
    my $this = shift;
    $this->{'ws'};
}

sub toString {
    return "[TokenWhitespace]";
}

sub scan  # static (Tokenizer t) : Token
{
    my ($class, $t) = @_;
    my $buf;
    while ($t->peekChar() =~ m![ \t\r\n]!) {
        $buf .= $t->getChar();
    }
    return S2::TokenWhitespace->new($buf);
}

sub asHTML {
    my ($this, $o) = @_;
    $o->write($this->{'ws'});
}

1;

