#!/usr/bin/perl
#

package S2::NodeForeachStmt;

use strict;
use S2::Node;
use S2::NodeVarDecl;
use S2::NodeVarRef;
use S2::NodeExpr;
use S2::NodeStmtBlock;
use vars qw($VERSION @ISA);

$VERSION = '1.0';
@ISA = qw(S2::Node);

sub new {
    my ($class) = @_;
    my $n = new S2::Node;
    bless $n, $class;
}

sub canStart {
    my ($class, $toker) = @_;
    return $toker->peek() == $S2::TokenKeyword::FOREACH
}

sub parse {
    my ($class, $toker) = @_;

    my $n = new S2::NodeForeachStmt;
    $n->setStart($n->requireToken($toker, $S2::TokenKeyword::FOREACH));

    if (S2::NodeVarDecl::canStart($toker)) {
        $n->addNode($n->{'vardecl'} = S2::NodeVarDecl->parse($toker));
    } else {
        $n->addNode($n->{'varref'} = S2::NodeVarRef->parse($toker));
    }

    # expression in parenthesis representing an array to iterate over:
    $n->requireToken($toker, $S2::TokenPunct::LPAREN);
    $n->addNode($n->{'listexpr'} = S2::NodeExpr->parse($toker));
    $n->requireToken($toker, $S2::TokenPunct::RPAREN);

    # and what to do on each element
    $n->addNode($n->{'stmts'} = S2::NodeStmtBlock->parse($toker));

    return $n;
}

sub check {
    my ($this, $l, $ck) = @_;

}

sub asS2 {
    my ($this, $o) = @_;
}

sub asPerl {
    my ($this, $bp, $o) = @_;
}

