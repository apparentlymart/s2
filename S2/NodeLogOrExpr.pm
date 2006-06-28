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
    S2::NodeLogAndExpr->canStart($toker);
}

sub parse {
    my ($class, $toker) = @_;
    my $n = new S2::NodeLogOrExpr;

    $n->{'lhs'} = parse S2::NodeLogAndExpr $toker;
    $n->addNode($n->{'lhs'});

    return $n->{'lhs'} unless
        $toker->peek() == $S2::TokenKeyword::OR;

    $n->eatToken($toker);

    $n->{'rhs'} = parse S2::NodeLogOrExpr $toker;
    $n->addNode($n->{'rhs'});

    return $n;
}

sub getType {
    my ($this, $ck) = @_;

    my $lt = $this->{'lhs'}->getType($ck);
    my $rt = $this->{'rhs'}->getType($ck);

    if (! $lt->equals($rt) || ! $lt->isBoolable()) {
        S2::error($this, "The left and right side of the 'or' expression must ".
                  "both be of either type bool or int.");
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

sub asParrot
{
    my ($self, $backend, $general, $main, $data) = @_;

    my ($success_label, $last_label) = ($backend->identifier,
        $backend->identifier);
    my $out_reg = $backend->register('P');
    my $cond_reg = $backend->register('I');

    # Short-circuit evaluation
    my $l_reg = $self->{lhs}->asParrot($backend, $general, $main, $data);
    $general->writeln("$cond_reg = istrue $l_reg");
    $general->writeln("eq $cond_reg, 1, $success_label");
    my $r_reg = $self->{rhs}->asParrot($backend, $general, $main, $data);
    $general->writeln("$out_reg = $r_reg");
    $general->writeln("goto $last_label");
    $general->writeln("$success_label:");
    $general->writeln("$out_reg = $l_reg");     # which will be true
    $general->writeln("$last_label:");

    return $out_reg;
}

1;

