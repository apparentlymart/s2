#!/usr/bin/perl
#

package S2::NodeProduct;

use strict;
use S2::Node;
use S2::NodeUnaryExpr;
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
    $S2::NodeUnaryExpr->canStart($toker);
}

sub parse {
    my ($class, $toker) = @_;

    my $lhs = parse S2::NodeUnaryExpr $toker;

    while ($toker->peek() == $S2::TokenPunct::MULT ||
           $toker->peek() == $S2::TokenPunct::DIV ||
           $toker->peek() == $S2::TokenPunct::MOD) {
        $lhs = parseAnother($toker, $lhs);
    }
    return $lhs;
}

sub parseAnother {
    my ($toker, $lhs) = @_;

    my $n = new S2::NodeProduct();

    $n->{'lhs'} = $lhs;
    $n->addNode($n->{'lhs'});

    $n->{'op'} = $toker->peek();
    $n->eatToken($toker);
    $n->skipWhite($toker);

    $n->{'rhs'} = parse S2::NodeUnaryExpr $toker;
    $n->addNode($n->{'rhs'});
    $n->skipWhite($toker);

    return $n;
}

sub getType {
    my ($this, $ck, $wanted) = @_;

    my $lt = $this->{'lhs'}->getType($ck, $wanted);
    my $rt = $this->{'rhs'}->getType($ck, $wanted);

    unless ($lt->equals($S2::Type::INT)) {
        die "Left hand side of " . $this->{'op'}->getPunct() . " operator is " .
            $lt->toString() . ", not an integer, at " .
            $this->{'lhs'}->getFilePos()->toString() . "\n";
    }

    unless ($rt->equals($S2::Type::INT)) {
        die "Right hand side of " . $this->{'op'}->getPunct() . " operator is " .
            $rt->toString() . ", not an integer, at " .
            $this->{'rhs'}->getFilePos()->toString() . "\n";
    }

    return $S2::Type::INT;
}

sub asS2 {
    my ($this, $o) = @_;
    $this->{'lhs'}->asS2($o);
    $o->write(" " . $this->{'op'}->getPunct() . " ");
    $this->{'rhs'}->asS2($o);
}

sub asPerl {
    my ($this, $bp, $o) = @_;
    $this->{'lhs'}->asPerl($bp, $o);

    if ($this->{'myType'} == $S2::Type::STRING) {
        $o->write(" . ");
    } elsif ($this->{'op'} == $S2::TokenPunct::PLUS) {
        $o->write(" + ");
    } elsif ($this->{'op'} == $S2::TokenPunct::MINUS) {
        $o->write(" - ");
    }
     
    $this->{'rhs'}->asPerl($bp, $o);
}

