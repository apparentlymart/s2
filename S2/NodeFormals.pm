#!/usr/bin/perl
#

package S2::NodeFormals;

use strict;
use S2::Node;
use vars qw($VERSION @ISA);

$VERSION = '1.0';
@ISA = qw(S2::Node);

sub new {
    my ($class, $formals) = @_;
    my $node = new S2::Node;
    $node->{'listFormals'} = $formals || [];
    bless $node, $class;
}

sub parse {
    my ($class, $toker, $isDecl) = @_;
    my $n = new S2::NodeFormals;
    my $count = 0;

    $n->requireToken($toker, $S2::TokenPunct::LPAREN);
    while ($toker->peek() != $S2::TokenPunct::RPAREN) {
        $n->requireToken($toker, $S2::TokenPunct::COMMA) if $count;
        $n->skipWhite($toker);

        my $nf = parse S2::NodeNamedType $toker;
        push @{$n->{'listFormals'}}, $nf;
        $n->addNode($nf);

        $n->skipWhite($toker);
        $count++;
    }
    $n->requireToken($toker, $S2::TokenPunct::RPAREN);
    return $n;
}

sub check {
    my ($this, $l, $ck) = @_;
    my %seen;
    foreach my $nt (@{$this->{'listFormals'}}) {
        my $name = $nt->getName();
        S2::error($nt, "Duplicate argument named $name") if $seen{$name}++;
        my $t = $nt->getType();
        unless ($ck->isValidType($t)) {
            S2::error($nt, "Unknown type " . $t->toString);
        }
    }
}

sub asS2 {
    my ($this, $o) = @_;
    return unless @{$this->{'listFormals'}};
    $o->write($this->toString());
}

sub toString {
    my ($this) = @_;
    return "(" . join(", ", map { $_->toString } 
                      @{$this->{'listFormals'}}) . ")";
}

sub getFormals { shift->{'listFormals'}; }

# FIXME: much not converted yet


