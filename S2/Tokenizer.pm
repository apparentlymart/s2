#!/usr/bin/perl
#

use strict;
use S2::Scanner;
use S2::FilePos;
use S2::TokenPunct;
use S2::TokenWhitespace;
use S2::TokenIdent;
use S2::TokenIntegerLiteral;
use S2::TokenPunct;
use S2::TokenComment;
use S2::TokenStringLiteral;

package S2::Tokenizer;

sub new # (fh) class method
{
    my ($class, $fh) = @_;

    my $this = {};
    bless $this, $class;
    
    if ($fh) { $this->{'sc'} = new S2::Scanner $fh; }
    $this->{'inString'} = 0;  # (accessed directly elsewhere)
    $this->{'peekedToken'} = undef;
    $this->{'masterTokenizer'} = $this;
    return $this;
}

sub getVarTokenizer # () method : Tokenizer
{
    my $this = shift;
    my $vt = new S2::Tokenizer undef;
    $vt->{'inString'} = 0;
    $vt->{'varToker'} = 1;
    
    # clone everything else
    $vt->{'masterTokenizer'} = $this->{'masterTokenizer'};
    $vt->{'sc'} = $this->{'sc'};
    
    # but don't clone this...
    if ($this->{'peekedToken'}) {
        die "Request to instantiate sub-tokenizer failed because " .
            "master tokenizer has a peeked token loaded already.\n";
    }

    return $vt;
}

sub release # () method : void
{
    my $this = shift;
    if ($this->{'peekedToken'}) {
        die "Sub-tokenizer had a peeked token when releasing.\n";
    }
}

sub peek # () method : Token
{
    my $this = shift;
    $this->{'peekedToken'} ||= $this->getToken();
    return $this->{'peekedToken'};
}

sub getToken # () method : Token
{
    my $this = shift;

    # return peeked token if we have one
    if (my $t = $this->{'peekedToken'}) {
        $this->{'peekedToken'} = undef;
        return $t;
    }

    my $pos = $this->getPos();
    my $nxtoken = $this->makeToken();
    $nxtoken->{'pos'} = $pos if $nxtoken;
    return $nxtoken;
}

sub getPos # () method : FilePos
{
    my $this = shift;
    return new S2::FilePos($this->{'sc'}->{'line'},
                                    $this->{'sc'}->{'col'});
}

sub makeToken # () method private : Token
{
    my $this = shift;

    my $nextChar = $this->{'sc'}->peek();
    return undef unless defined $nextChar;

    if ($nextChar eq '$') {
        return S2::TokenPunct->scan($this);
    }

    if ($this->{'inString'}) {
        return S2::TokenStringLiteral->scan($this);
    }

    if ($nextChar eq " " || $nextChar eq "\t" || 
        $nextChar eq "\n" || $nextChar eq "\r") {
        return S2::TokenWhitespace->scan($this);
    }
    
    if (S2::TokenIdent->canStart($this)) {
        return S2::TokenIdent->scan($this);
    }

    if ($nextChar =~ /\d/) {
        return S2::TokenIntegerLiteral->scan($this);
    }

    if ($nextChar eq '<' || $nextChar eq '>' ||
        $nextChar eq '=' || $nextChar eq '!' ||
        $nextChar eq ';' || $nextChar eq ':' ||
        $nextChar eq '+' || $nextChar eq '-' ||
        $nextChar eq '*' || $nextChar eq '/' ||
        $nextChar eq '&' || $nextChar eq '|' ||
        $nextChar eq '{' || $nextChar eq '}' ||
        $nextChar eq '[' || $nextChar eq ']' ||
        $nextChar eq '(' || $nextChar eq ')' ||
        $nextChar eq '.' || $nextChar eq ',' ||
        $nextChar eq '?' || $nextChar eq '%') {
        return S2::TokenPunct->scan($this);
    }
    
    if ($nextChar eq '#') {
        return S2::TokenComment->scan($this);
    }
    
    if ($nextChar eq '"') {
        return S2::TokenStringLiteral->scan($this);
    }
    
    die "Parse error!  Unknown character '" . $nextChar .
        "' (" . (ord $nextChar) . ") encountered at " .
        $this->locationString();
}

sub locationString # () : string 
{
    my $this = shift;
    return $this->{'sc'}->locationString();
}

sub peekChar # () : char
{
    my $this = shift;
    return $this->{'sc'}->peek();
}

sub getChar # () : char
{
    my $this = shift;
    return $this->{'sc'}->getChar();
}

sub getRealChar # () : char
{
    my $this = shift;
    return $this->{'sc'}->getRealChar();
}

sub forceNextChar # (ch) : void
{
    my $this = shift;
    my $ch = shift;
    return $this->{'sc'}->forceNextChar($ch);
}


1;
