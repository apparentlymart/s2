#!/usr/bin/perl
#

package S2::NodeLogOrExpr;

use strict;
use S2::Node;
use S2::NodeLogAndExpr;
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
    $S2::NodeLogAndExpr->canStart($toker);
}

sub parse {
    my ($class, $toker) = @_;
    my $n = new S2::NodeLogOrExpr;

    $n->{'lhs'} = parse S2::NodeLogAndExpr $toker;
    $n->addNode($n->{'lhs'});

    return $n->{'lhs'} unless
        $toker->peek() == $S2::TokenPunct::OR;

    $n->eatToken($toker);

    $n->{'rhs'} = parse S2::NodeLogAndExpr $toker;
    $n->addNode($n->{'rhs'});

    return $n;
}

sub getType {
    my ($this, $ck) = @_;

    my $lt = $this->{'lhs'}->getType($ck);
    my $rt = $this->{'rhs'}->getType($ck);

    if (! $lt->equals($rt) || ! $lt->isBoolable()) {
        die "The left and right side of the 'or' expression must ".
            "both be of either type bool or int at ".
            $this->getFilePos->toString . "\n";
    }

    return $S2::Type::BOOL;
}

sub asS2 {
    my ($this, $o) = @_;
    $this->{'lhs'}->asS2($o);
    $o->write(" or ");
    $this->{'rhs'}->asS2($o);
}

sub asPerl {
    my ($this, $bp, $o) = @_;
    $this->{'lhs'}->asPerl($bp, $o);
    $o->write(" || ");
    $this->{'rhs'}->asPerl($bp, $o);
}

