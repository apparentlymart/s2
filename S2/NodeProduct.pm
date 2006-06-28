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
    S2::NodeUnaryExpr->canStart($toker);
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
        S2::error($this->{'lhs'}, "Left hand side of " . $this->{'op'}->getPunct() . " operator is " .
                  $lt->toString() . ", not an integer.");
    }

    unless ($rt->equals($S2::Type::INT)) {
        S2::error($this->{'rhs'}, "Right hand side of " . $this->{'op'}->getPunct() . " operator is " .
                  $rt->toString() . ", not an integer.");
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

    $o->write("int(") if $this->{'op'} == $S2::TokenPunct::DIV;
    $this->{'lhs'}->asPerl($bp, $o);

    if ($this->{'op'} == $S2::TokenPunct::MULT) {
        $o->write(" * ");
    } elsif ($this->{'op'} == $S2::TokenPunct::DIV) {
        $o->write(" / ");
    } elsif ($this->{'op'} == $S2::TokenPunct::MOD) {
        $o->write(" % ");
    }
    
    $this->{'rhs'}->asPerl($bp, $o);
    $o->write(")") if $this->{'op'} == $S2::TokenPunct::DIV;     
}

sub asParrot
{
    my ($self, $backend, $general, $main, $data) = @_;

    my $l_reg = $self->{lhs}->asParrot($backend, $general, $main, $data);
    my $r_reg = $self->{rhs}->asParrot($backend, $general, $main, $data);
    my $out_reg = $backend->register('P');

    if ($self->{op} == $S2::TokenPunct::MULT) {
        $general->writeln("$out_reg = n_mul $l_reg, $r_reg");
    } elsif ($self->{op} == $S2::TokenPunct::DIV) {
        $general->writeln("$out_reg = n_fdiv $l_reg, $r_reg");
    } elsif ($self->{op} == $S2::TokenPunct::MOD) {
        $general->writeln("$out_reg = n_mod $l_reg, $r_reg");
    }

    return $out_reg;
}

1;

