#!/usr/bin/perl
#

package S2::NodeSet;

use strict;
use S2::Node;
use S2::NodeExpr;
use vars qw($VERSION @ISA);

$VERSION = '1.0';
@ISA = qw(S2::Node);

sub new {
    my ($class) = @_;
    my $node = new S2::Node;
    bless $node, $class;
}

sub canStart {
    my ($class, $toker) = @_;
    return $toker->peek() == $S2::TokenKeyword::SET;
}

sub parse {
    my ($class, $toker) = @_;

    my $nkey; # NodeText
    my $ns = new S2::NodeSet;

    $ns->setStart($ns->requireToken($toker, $S2::TokenKeyword::SET));
    
    $nkey = parse S2::NodeText $toker;
    $ns->addNode($nkey);
    $ns->{'key'} = $nkey->getText();

    $ns->requireToken($toker, $S2::TokenPunct::ASSIGN);

    $ns->{'value'} = parse S2::NodeExpr $toker;
    $ns->addNode($ns->{'value'});
    
    $ns->requireToken($toker, $S2::TokenPunct::SCOLON);
    return $ns;
}


sub asS2 {
    my ($this, $o) = @_;
    $o->tabwrite("set ");
    $o->write(S2::Backend->quoteString($this->{'key'}));
    $o->write(" = ");
    $this->{'value'}->asS2($o);
    $o->writeln(";");
}

sub check {
    my ($this, $l, $ck) = @_;

    my $ltype = $ck->propertyType($this->{'key'});
    $ck->setInFunction(0);

    unless ($ltype) {
        die "Can't set non-existent property '$this->{'key'}' at ".
            $this->getFilePos()->toString() . "\n";
    }

    my $rtype = $this->{'value'}->getType($ck, $ltype);
    
    unless ($ltype->equals($rtype)) {
        die "Property value is of wrong type at " .
            $this->getFilePos()->toString() . "\n";
    }

    # simple case... assigning a primitive
    if ($ltype->isPrimitive()) {
        # TODO: check that value.isLiteral()
        # TODO: check value's type matches
        return;
    }

    my $base = new S2::Type $ltype->baseType();
    if ($base->isPrimitive()) {
        return;
    } elsif (! defined $ck->getClass($ltype->baseType())) {
        die "Can't set property of unknown type at " .
            $this->getFilePos()->toString() . "\n";
    }
}

sub asPerl {
    my ($this, $bp, $o) = @_;
    $o->tabwrite("register_set(" .
                 $bp->getLayerIdString() . "," .
                 $bp->quoteString($this->{'key'}) . ",");
    $this->{'value'}->asPerl($bp, $o);
    $o->writeln(");");
    return;
}
