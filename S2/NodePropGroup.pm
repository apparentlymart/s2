#!/usr/bin/perl
#

package S2::NodePropGroup;

use strict;
use S2::Node;
use S2::NodeProperty;
use S2::NodeSet;
use vars qw($VERSION @ISA);

$VERSION = '1.0';
@ISA = qw(S2::Node);

sub new {
    my ($class) = @_;
    my $node = new S2::Node;
    $node->{'groupident'} = "";
    $node->{'set_list'} = 0;  # true if setting a propgroup list
    $node->{'list_props'} = []; # array of NodeProperty 
    $node->{'list_sets'} = []; # array of NodeSet
    $node->{'set_name'} = 0;  # true if setting the propgroup name
    $node->{'name'} = undef;
    bless $node, $class;
}

sub canStart {
    my ($class, $toker) = @_;
    return $toker->peek() == $S2::TokenKeyword::PROPGROUP;
}

sub parse {
    my ($class, $toker) = @_;
    my $n = new S2::NodePropGroup;

    $n->setStart($n->requireToken($toker, $S2::TokenKeyword::PROPGROUP));
    my $ident = $n->getIdent($toker);
    $n->{'groupident'} = $ident->getIdent();
    
    if ($toker->peek() == $S2::TokenPunct::LBRACE) {
        $n->{'set_list'} = 1;
        $n->requireToken($toker, $S2::TokenPunct::LBRACE);
        my $node;
        do
        {
            $node = undef;
            if (S2::NodeProperty->canStart($toker)) {
                $node = S2::NodeProperty->parse($toker);
                push @{$n->{'list_props'}}, $node;
            }
            if (S2::NodeSet->canStart($toker)) {
                $node = S2::NodeSet->parse($toker);
                push @{$n->{'list_sets'}}, $node;
            }
            $n->addNode($node) if $node;
        } while ($node);
        $n->requireToken($toker, $S2::TokenPunct::RBRACE);
    } else {
        $n->{'set_name'} = 1;
        $n->requireToken($toker, $S2::TokenPunct::ASSIGN);
        my $sl = $n->getStringLiteral($toker);
        $n->{'name'} = $sl->getString();
        $n->requireToken($toker, $S2::TokenPunct::SCOLON);
    }

    return $n;
}

sub check {
    my ($this, $l, $ck) = @_;

    if ($this->{'set_list'}) {
        foreach my $prop (@{$this->{'list_props'}}, @{$this->{'list_sets'}}) {
            $prop->check($l, $ck);
        }
    }
}

sub asS2 {
    my ($this, $o) = @_;
}

sub asPerl {
    my ($this, $bp, $o) = @_;

    if ($this->{'set_name'}) {
        $o->tabwriteln("register_propgroup_name(" .
                       $bp->getLayerIDString() . "," .
                       "'$this->{groupident}', " .
                       $bp->quoteString($this->{'name'}) . ");");
        return;
    }

    foreach (@{$this->{'list_props'}}, @{$this->{'list_sets'}}) {
        $_->asPerl($bp, $o);
    }
    
    $o->tabwriteln("register_propgroup_props(" . 
                   $bp->getLayerIDString() . "," .
                   "'$this->{groupident}', [".
                   join(', ', map { $bp->quoteString($_->getName) } @{$this->{'list_props'}}) .
                   "]);");
}
