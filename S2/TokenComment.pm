#!/usr/bin/perl
#

package S2::TokenComment;

use strict;
use S2::Token;
use vars qw($VERSION @ISA);

$VERSION = '1.0';
@ISA = qw(S2::Token);

sub new
{
    my ($class, $com) = @_;
    bless {
        'com' => $com,
    }, $class;
}

sub getComment
{
    shift->{'com'};
}

sub toString
{
    "[TokenComment]";
}

sub isNecessary { return 0; }

sub scan
{
    my ($class, $t) = @_;
    my $buf;
    while ($t->peekChar() != '\n') {
        $buf .= $t->getChar();
    }
    return S2::TokenComment->new($buf);
}

sub asHTML
{
    my ($this, $o) = @_;
    $o->write("<span class=\"c\">$this->{'com'}</span>");
}

1;

