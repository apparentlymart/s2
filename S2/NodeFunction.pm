#!/usr/bin/perl
#

package S2::NodeFunction;

use strict;
use S2::Node;
use S2::NodeFormals;
use S2::NodeStmtBlock;
use vars qw($VERSION @ISA);

$VERSION = '1.0';
@ISA = qw(S2::Node);

sub new {
    my ($class) = @_;
    my $node = new S2::Node;
    bless $node, $class;
}

sub getDocString { shift->{'docstring'}; }

sub canStart {
    my ($class, $toker) = @_;
    return $toker->peek() == $S2::TokenKeyword::FUNCTION;
}

sub parse {
    my ($class, $toker, $isDecl) = @_;
    my $n = new S2::NodeFunction;

    # get the function keyword
    $n->setStart($n->requireToken($toker, $S2::TokenKeyword::FUNCTION));

    # is the builtin keyword on?
    if ($toker->peek() == $S2::TokenKeyword::BUILTIN) {
        $n->{'builtin'} = 1;
        $n->eatToken($toker);
    }

    # the class name or function name (if no class)
    $n->{'name'} = $n->getIdent($toker);

    # check for a double colon
    if ($toker->peek() == $S2::TokenPunct::DCOLON) {
        # so last ident was the class name
        $n->{'classname'} = $n->{'name'};
        $n->eatToken($toker);
        $n->{'name'} = $n->getIdent($toker);
    }

    # Argument list is optional.
    if ($toker->peek() == $S2::TokenPunct::LPAREN) {
        $n->addNode($n->{'formals'} = S2::NodeFormals->parse($toker));
    }

    # return type is optional too.
    if ($toker->peek() == $S2::TokenPunct::COLON) {
        $n->requireToken($toker, $S2::TokenPunct::COLON);
        $n->addNode($n->{'rettype'} = S2::NodeType->parse($toker));
    }

    # docstring
    if ($toker->peek()->isa('S2::TokenStringLiteral')) {
        $n->{'docstring'} = $n->eatToken($toker)->getString();
    }

    # if inside a class declaration, only a declaration now.
    if ($isDecl || $n->{'builtin'}) {
        $n->requireToken($toker, $S2::TokenPunct::SCOLON);
        return $n;
    }
    
    # otherwise, keep parsing the function definition.
    $n->{'stmts'} = parse S2::NodeStmtBlock $toker;
    $n->addNode($n->{'stmts'});

    return $n;
}


sub asS2 {
    my ($this, $o) = @_;
}

sub asPerl {
    my ($this, $bp, $o) = @_;
}

sub check {
    my ($this, $l, $ck) = @_;
}

