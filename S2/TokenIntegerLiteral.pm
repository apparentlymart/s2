#!/usr/bin/perl
#

package S2::TokenIntegerLiteral;

use strict;
use S2::Token;
use vars qw($VERSION @ISA);

$VERSION = '1.0';
@ISA = qw(S2::Token);

sub new
{
    my $val = shift;
    bless {
        'val' => $val+0,
    };
}

sub getInteger
{
    my $this = shift;
    $this->{'val'};
}

sub asS2
{
    my ($this, $o) = @_;
    $o->write($this->{'val'});
}

sub asHTML
{
    my ($this, $o) = @_;
    $o->write("<span class=\"n\">$this->{'val'}</span>");
}

sub asPerl
{
    my ($this, $bp, $o) = @_;
    $o->write($this->{'val'});
}

sub toString
{
    my $this = shift;
    "[TokenIntegerLiteral] = $this->{'val'}";
}

sub scan
{
    my $t = shift;
    my $buf;
    while ($t->peekChar() =~ /\d/) {
        $buf .= $t->getChar();
    }
    return new($buf);
}

1;

