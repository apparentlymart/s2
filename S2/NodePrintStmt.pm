#!/usr/bin/perl
#

package S2::NodePrintStmt;

use strict;
use S2::Node;
use S2::Parrot::Embedded;
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
    my $p = $toker->peek();
    return
        $p->isa('S2::TokenStringLiteral') ||
        $p == $S2::TokenKeyword::PRINT ||
        $p == $S2::TokenKeyword::PRINTLN;
}

sub parse {
    my ($class, $toker) = @_;

    my $n = new S2::NodePrintStmt;
    my $t = $toker->peek();

    if ($t == $S2::TokenKeyword::PRINT) {
        $n->setStart($n->eatToken($toker));
    }
    if ($t == $S2::TokenKeyword::PRINTLN) {
        $n->setStart($n->eatToken($toker));
        $n->{'doNewline'} = 1;
    }

    $t = $toker->peek();
    if ($t->isa("S2::TokenIdent") && $t->getIdent() eq "safe") {
        $n->{'safe'} = 1;
        $n->eatToken($toker);
    }

    $n->addNode($n->{'expr'} = S2::NodeExpr->parse($toker));
    $n->requireToken($toker, $S2::TokenPunct::SCOLON);
    return $n;
}

sub check {
    my ($this, $l, $ck) = @_;
    my $t = $this->{'expr'}->getType($ck);
    return if $t->equals($S2::Type::INT) ||
        $t->equals($S2::Type::STRING);
    unless ($this->{'expr'}->makeAsString($ck)) {
        S2::error($this, "Print statement must print an expression of type int or string, not " .
                  $t->toString);
    }
}

sub asS2 {
    my ($this, $o) = @_;
    $o->tabwrite($this->{'doNewline'} ? "println " : "print ");
    $this->{'expr'}->asS2($o);
    $o->writeln(";");
}

sub asPerl {
    my ($this, $bp, $o) = @_;
    if ($bp->oo) {
        if ($bp->untrusted() || $this->{'safe'}) {
            $o->tabwrite("\$_ctx->_print_safe->(");
        } else {
            $o->tabwrite("\$_ctx->_print(");
        }
    }
    else {
        if ($bp->untrusted() || $this->{'safe'}) {
            $o->tabwrite("\$S2::pout_s->(");
        } else {
            $o->tabwrite("\$S2::pout->(");
        }
    }
    $this->{'expr'}->asPerl($bp, $o);
    $o->write(" . \"\\n\"") if $this->{'doNewline'};
    $o->writeln(");");
}

sub pout_s
{
    $S2::pout_s->(@_);
}

sub pout
{
    $S2::pout->(@_);
}

sub asParrot
{
    my ($self, $backend, $general, $main, $data) = @_;

    my $str_reg = $self->{expr}->asParrot($backend, $general, $main, $data);

    my $arg_reg = $backend->register('P');
    my $ret_reg = $backend->register('P');
    $general->writeln($arg_reg . ' = new .String');
    $general->writeln($arg_reg . " = $str_reg");

    if ($self->{doNewline}) {
        my $reg = $backend->register('P');
        $general->writeln($reg . ' = new .String, "\n"');
        $general->writeln("n_concat $arg_reg, $reg");
    }

    my $func_name = 'S2::NodePrintStmt::pout_s';
    $func_name = 'S2::NodePrintStmt::pout' if not $backend->untrusted and
        not $self->{safe};

    $general->writeln(S2::Parrot::Embedded->assemble_perl_function_call(
        $func_name, [ $arg_reg ], $ret_reg, sub { $backend->register('P') }));
}

1;

