#!/usr/bin/perl
#

package S2::NodeIncExpr;

use strict;
use S2::Node;
use S2::NodeTerm;
use vars qw($VERSION @ISA);

$VERSION = '1.0';
@ISA = qw(S2::Node);

sub new {
    my ($class, $n) = @_;
    my $node = new S2::Node;
    bless $node, $class;
}

sub canStart {
    my ($class, $toker) = @_;
    return $toker->peek() == $S2::TokenPunct::INC ||
        $toker->peek() == $S2::TokenPunct::DEC ||
        S2::NodeTerm->canStart($toker);
}

sub parse {
    my ($class, $toker) = @_;

    my $n = new S2::NodeIncExpr;

    if ($toker->peek() == $S2::TokenPunct::INC ||
        $toker->peek() == $S2::TokenPunct::DEC) {
        $n->{'bPre'} = 1;
        $n->{'op'} = $toker->peek();
        $n->setStart($n->eatToken($toker));
        $n->skipWhite($toker);
    }

    my $expr = parse S2::NodeTerm $toker;
    
    if ($toker->peek() == $S2::TokenPunct::INC ||
        $toker->peek() == $S2::TokenPunct::DEC) {
        if ($n->{'bPre'}) {
            die "Unexpected " . $toker->peek()->getPunct() . "\n";
        }
        $n->{'bPost'} = 1;
        $n->{'op'} = $toker->peek();
        $n->eatToken($toker);
        $n->skipWhite($toker);
    }

    if ($n->{'bPre'} || $n->{'bPost'}) {
        $n->{'expr'} = $expr;
        return $n;
    }

    return $expr;
}

sub getType {
    my ($this, $ck, $wanted) = @_;
    my $t = $this->{'expr'}->getType($ck);

    unless ($this->{'expr'}->isLValue() &&
            $t == $S2::Type::INT) {
        die "Post/pre-increment must operate on an integer lvalue at ".
            $this->{'expr'}->getFilePos->toString . "\n";
    }

    return $t;
}

sub asS2 {
    my ($this, $o) = @_;
    if ($this->{'bPre'}) { $o->write($this->{'op'}->getPunct()); }
    $this->{'expr'}->asS2($o);
    if ($this->{'bPost'}) { $o->write($this->{'op'}->getPunct()); }
}

sub asPerl {
    my ($this, $bp, $o) = @_;
    if ($this->{'bPre'}) { $o->write($this->{'op'}->getPunct()); }
    $this->{'expr'}->asPerl($bp, $o);
    if ($this->{'bPost'}) { $o->write($this->{'op'}->getPunct()); }
}

