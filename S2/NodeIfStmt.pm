#!/usr/bin/perl
#

package S2::NodeIfStmt;

use strict;
use S2::Node;
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
    return $toker->peek() == $S2::TokenKeyword::IF;
}

sub parse {
    my ($class, $toker) = @_;

    my $n = new S2::NodeIfStmt;
    $n->{'elseifblocks'} = [];
    $n->{'elseifexprs'} = [];

    $n->setStart($n->requireToken($toker, $S2::TokenKeyword::IF));
    $n->requireToken($toker, $S2::TokenPunct::LPAREN);
    $n->addNode($n->{'expr'} = S2::NodeExpr->parse($toker));
    $n->requireToken($toker, $S2::TokenPunct::RPAREN);
    $n->addNode($n->{'thenblock'} = S2::NodeStmtBlock->parse($toker));
    
    while ($toker->peek() == $S2::TokenKeyword::ELSEIF) {
        $n->eatToken($toker);
        $n->requireToken($toker, $S2::TokenPunct::LPAREN);
        my $expr = S2::NodeExpr->parse($toker);
        $n->addNode($expr);
        $n->requireToken($toker, $S2::TokenPunct::RPAREN);
        push @{$n->{'elseifexprs'}}, $expr;

        my $nie = S2::NodeStmtBlock->parse($toker);
        $n->addNode($nie);
        push @{$n->{'elseifblocks'}}, $nie;
    }

    if ($toker->peek() == $S2::TokenKeyword::ELSE) {
        $n->eatToken($toker);
        $n->addNode($n->{'elseblock'} =
                    S2::NodeStmtBlock->parse($toker));
    }

    return $n;
}

# returns true if and only if the 'then' stmtblock ends in a
# return statement, the 'else' stmtblock is non-null and ends
# in a return statement, and any elseif stmtblocks end in a return
# statement.
sub willReturn {
    my ($this) = @_;
    return 0 unless $this->{'elseblock'};
    return 0 unless $this->{'thenblock'}->willReturn();
    return 0 unless $this->{'elseblock'}->willReturn();
    foreach (@{$this->{'elseifblocks'}}) {
        return 0 unless $_->willReturn();
    }
    return 1;
}

sub check {
    my ($this, $l, $ck) = @_;

    my $t = $this->{'expr'}->getType($ck);
    S2::error($this, "Non-boolean if test") unless $t->isBoolable();

    $this->{'thenblock'}->check($l, $ck);

    foreach my $ne (@{$this->{'elseifexprs'}}) {
        $t = $ne->getType($ck);
        S2::error($ne, "Non-boolean if test") unless $ne->isBoolable();
    }

    foreach my $sb (@{$this->{'elseifblocks'}}) {
        $sb->check($l, $ck);
    }

    $this->{'elseblock'}->check($l, $ck) if
        $this->{'elseblock'};
}

sub asS2 {
    my ($this, $o) = @_;
}

sub asPerl {
    my ($this, $bp, $o) = @_;
}
