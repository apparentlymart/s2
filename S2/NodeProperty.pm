#!/usr/bin/perl
#

package S2::NodeProperty;

use strict;
use S2::Node;
use S2::NodeNamedType;
use vars qw($VERSION @ISA);

$VERSION = '1.0';
@ISA = qw(S2::Node);

sub new {
    my ($class) = @_;
    my $node = new S2::Node;
    $node->{'nt'} = undef;
    $node->{'pairs'} = [];
    $node->{'builtin'} = 0;
    $node->{'use'} = 0;
    $node->{'hide'} = 0;
    $node->{'uhName'} = undef; # if use or hide, then this is property to use/hide
    bless $node, $class;
}

sub canStart {
    my ($class, $toker) = @_;
    return $toker->peek() == $S2::TokenKeyword::PROPERTY;
}

sub parse {
    my ($class, $toker) = @_;
    my $n = new S2::NodeProperty;
    $n->{'pairs'} = [];

    $n->setStart($n->requireToken($toker, $S2::TokenKeyword::PROPERTY));
    
    if ($toker->peek() == $S2::TokenKeyword::PROPERTY) {
        $n->{'builtin'} = 1;
        $n->eatToken($toker);
    }

    # parse the use/hide case
    if ($toker->peek()->isa('S2::TokenIdent')) {
        my $ident = $toker->peek()->getIdent();
        if ($ident eq "use" || $ident eq "hide") {
            $n->{'use'} = 1 if $ident eq "use";
            $n->{'hide'} = 1 if $ident eq "hide";
            $n->eatToken($toker);

            my $t = $toker->peek();
            unless ($t->isa('S2::TokenIdent')) {
                die "Expecting identifier after $ident at " .
                    $t->getFilePos()->toString() . "\n";
            }
            
            $n->{'uhName'} = $t->getIdent();
            $n->eatToken($toker);
            $n->requireToken($toker, $S2::TokenPunct::SCOLON);
        }
    }

    $n->addNode($n->{'nt'} = S2::NodeNamedType->parse($toker));
    
    my $t = $toker->peek();
    if ($t == $S2::TokenPunct::SCOLON) {
        $n->eatToken($toker);
        return $n;
    }

    $n->requireToken($toker, $S2::TokenPunct::LBRACE);
    while (S2::NodePropertyPair::canStart($toker)) {
        my $pair = S2::NodePropertyPair::parse($toker);
        push @{$n->{'tokenlist'}}, $pair;
        push @{$n->{'pairs'}}, $pair;
    }
    $n->requireToken($toker, $S2::TokenPunct::BBRACE);        

    return $n;
}


sub getText { shift->{'text'}; }

sub asS2 {
    my ($this, $o) = @_;
    $o->write(S2::Backend::quoteString($this->{'text'}));
}

