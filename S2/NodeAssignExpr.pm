#!/usr/bin/perl
#

package S2::NodeAssignExpr;

use strict;
use S2::Node;
use S2::NodeCondExpr;
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
    S2::NodeCondExpr->canStart($toker);
}

sub parse {
    my ($class, $toker) = @_;
    my $n = new S2::NodeAssignExpr;

    $n->{'lhs'} = parse S2::NodeCondExpr $toker;
    $n->addNode($n->{'lhs'});

    if ($toker->peek() == $S2::TokenPunct::ASSIGN) {
        $n->{'op'} = $toker->peek();
        $n->eatToken($toker);
    } else {
        return $n->{'lhs'};
    }

    $n->{'rhs'} = parse S2::NodeCondExpr $toker;
    $n->addNode($n->{'rhs'});

    return $n;
}

sub getType {
    my ($this, $ck, $wanted) = @_;

    my $lt = $this->{'lhs'}->getType($ck, $wanted);
    my $rt = $this->{'rhs'}->getType($ck, $lt);

    if ($lt->isReadOnly()) {
        die("Left-hand side of assignment at " . $this->getFilePos()->toString() .
            " is a read-only value.\n");
    }

    if (! $this->{'lhs'}->isa('S2::NodeTerm') ||
        ! $this->{'lhs'}->isLValue()) {
        die "Left-hand side of assignment at " . $this->getFilePos()->toString() .
            " must be an lvalue.\n";
    }

    return $lt if $ck->typeIsa($rt, $lt);

    # types don't match, but maybe class for left hand side has
    # a constructor which takes a string. 
    if ($rt->equals($S2::Type::STRING) && $ck->isStringCtor($lt)) {
        $rt = $this->{'rhs'}->getType($ck, $lt);  # FIXME: can remove this line?
        return $lt if $lt->equals($rt);
    }

    die("Can't assign type " . $rt->toString . " to " . $lt->toString . " at " .
        $this->getFilePos->toString . "\n");
}

sub asS2 {
    my ($this, $o) = @_;
    $this->{'lhs'}->asS2($o);
    if ($this->{'op'}) {
        $o->write(" = ");
        $this->{'rhs'}->asS2($o);
    }
}

sub asPerl {
    my ($this, $bp, $o) = @_;
    $this->{'lhs'}->asPerl($bp, $o);
    if ($this->{'op'}) {
        $o->write(" = ");
        $this->{'rhs'}->asPerl($bp, $o);
    }
}

