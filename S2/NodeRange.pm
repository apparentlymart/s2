#!/usr/bin/perl
#

package S2::NodeRange;

use strict;
use S2::Node;
use S2::NodeLogOrExpr;
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
    S2::NodeLogOrExpr->canStart($toker);
}

sub parse {
    my ($class, $toker) = @_;
    my $n = new S2::NodeRange;

    $n->{'lhs'} = parse S2::NodeLogOrExpr $toker;
    $n->addNode($n->{'lhs'});

    return $n->{'lhs'} unless
        $toker->peek() == $S2::TokenPunct::DOTDOT;

    $n->eatToken($toker);

    $n->{'rhs'} = parse S2::NodeLogOrExpr $toker;
    $n->addNode($n->{'rhs'});

    return $n;
}

sub getType {
    my ($this, $ck, $wanted) = @_;

    my $lt = $this->{'lhs'}->getType($ck, $wanted);
    my $rt = $this->{'rhs'}->getType($ck, $wanted);

    unless ($lt->equals($S2::Type::INT)) {
        die "Left operand of range operator is not an integer at ".
            $this->getFilePos->toString . "\n";
    }
    unless ($rt->equals($S2::Type::INT)) {
        die "Right operand of range operator is not an integer at ".
            $this->getFilePos->toString . "\n";
    }

    my $ret = new S2::Type "int";
    $ret->makeArrayOf();
    return $ret;
}

sub asS2 {
    my ($this, $o) = @_;
    $this->{'lhs'}->asS2($o);
    $o->write(" .. ");
    $this->{'rhs'}->asS2($o);
}

sub asPerl {
    my ($this, $bp, $o) = @_;
    $o->write("[");
    $this->{'lhs'}->asPerl($bp, $o);
    $o->write(" .. ");
    $this->{'rhs'}->asPerl($bp, $o);
    $o->write("]");
}

sub asParrot
{
    my ($self, $backend, $general, $main, $data) = @_;

    my $start_reg = $self->{lhs}->asParrot($backend, $general, $main, $data);
    my $end_reg = $self->{rhs}->asParrot($backend, $general, $main, $data);

    my $out_reg = $backend->register('P');
    $general->writeln("$out_reg = new .ResizablePMCArray");

    my ($loop_lbl, $last_lbl) = ($backend->identifier, $backend->identifier);
    $general->writeln("$loop_lbl: gt $start_reg, $end_reg, $last_lbl");
    $general->writeln("push $out_reg, $start_reg");
    $general->writeln("$start_reg = clone $start_reg");
    $general->writeln("inc $start_reg");
    $general->writeln("goto $loop_lbl");
    $general->writeln("$last_lbl:");

    return $out_reg;
}

