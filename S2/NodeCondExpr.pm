#!/usr/bin/perl
#

package S2::NodeCondExpr;

use strict;
use warnings;
use S2::Node;
use S2::NodeRange;
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
    S2::NodeRange->canStart($toker);
}

sub parse {
    my ($class, $toker) = @_;
    my $n = new S2::NodeCondExpr;

    $n->{'test_expr'} = parse S2::NodeRange $toker;
    $n->addNode($n->{'test_expr'});

    return $n->{'test_expr'} unless
        $toker->peek() == $S2::TokenPunct::QMARK;

    $n->eatToken($toker);

    $n->{'true_expr'} = parse S2::NodeRange $toker;
    $n->addNode($n->{'true_expr'});
    $n->requireToken($toker, $S2::TokenPunct::COLON);

    $n->{'false_expr'} = parse S2::NodeRange $toker;
    $n->addNode($n->{'false_expr'});

    return $n;
}

sub getType {
    my ($this, $ck) = @_;

    my $ctype = $this->{'test_expr'}->getType($ck);
    unless ($ctype->isBoolable()) {
        S2::error($this, "Conditional expression not of type boolean.");
    }

    my $lt = $this->{'true_expr'}->getType($ck);
    my $rt = $this->{'false_expr'}->getType($ck);
    unless ($lt->equals($rt)) {
        S2::error($this, "Types don't match in conditional expression.");
    }
    return $lt;
}

sub asS2 {
    my ($this, $o) = @_;
    $this->{'test_expr'}->asS2($o);
    $o->write(" ? ");
    $this->{'true_expr'}->asS2($o);
    $o->write(" : ");
    $this->{'false_expr'}->asS2($o);
}

sub asPerl {
    my ($this, $bp, $o) = @_;
    $o->write("(");
    $this->{'test_expr'}->asPerl_bool($bp, $o);
    $o->write(" ? ");
    $this->{'true_expr'}->asPerl($bp, $o);
    $o->write(" : ");
    $this->{'false_expr'}->asPerl($bp, $o);
    $o->write(")");
}

sub asParrot
{
    my ($self, $backend, $general, $main, $data) = @_;

    my ($false_label, $last_label) = ($backend->identifier,
        $backend->identifier);
    my $cond_reg =
        $self->{test_expr}->asParrot($backend, $general, $main, $data);
    my $out_reg = $backend->register('P');
    my $cmp_reg = $backend->register('I');

    $general->writeln("$cmp_reg = istrue $cond_reg");
    $general->writeln("eq $cmp_reg, 0, $false_label");
    my $true_reg =
        $self->{true_expr}->asParrot($backend, $general, $main, $data);
    $general->writeln("$out_reg = $true_reg");
    $general->writeln("goto $last_label");
    $general->writeln("$false_label:");
    my $false_reg =
        $self->{false_expr}->asParrot($backend, $general, $main, $data);
    $general->writeln("$out_reg = $false_reg");
    $general->writeln("$last_label:");

    return $out_reg;
}

1;

