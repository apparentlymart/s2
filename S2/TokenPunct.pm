#!/usr/bin/perl
#

package S2::TokenPunct;

use strict;
use S2::Token;
use vars qw($VERSION @ISA
            $LT $LTE $GTE $GT $EQ $NE $ASSIGN $INCR $PLUS
            $DEC $MINUS $DEREF $SCOLON $COLON $DCOLON $LOGAND
            $BITAND $LOGOR $BITOR $MULT $DIV $MOD $NOT $DOT
            $DOTDOT $LBRACE $RBRACE $LBRACK $RBRACK $LPAREN
            $RPAREN $COMMA $QMARK $DOLLAR $HASSOC
            );

$VERSION = '1.0';
@ISA = qw(S2::Token);

$LTE    = new S2::TokenPunct '<=';
$LT     = new S2::TokenPunct '<';
$GTE    = new S2::TokenPunct '>=';
$GT     = new S2::TokenPunct '>';
$EQ     = new S2::TokenPunct "==";
$NE     = new S2::TokenPunct "!=";
$ASSIGN = new S2::TokenPunct "=";
$INCR   = new S2::TokenPunct "++";
$PLUS   = new S2::TokenPunct "+";
$DEC    = new S2::TokenPunct "--";
$MINUS  = new S2::TokenPunct "-";
$DEREF  = new S2::TokenPunct "->";
$SCOLON = new S2::TokenPunct ";";
$COLON  = new S2::TokenPunct ":";
$DCOLON = new S2::TokenPunct "::";
$LOGAND = new S2::TokenPunct "&&";
$BITAND = new S2::TokenPunct "&";
$LOGOR  = new S2::TokenPunct "||";
$BITOR  = new S2::TokenPunct "|";
$MULT   = new S2::TokenPunct "*";
$DIV    = new S2::TokenPunct "/";
$MOD    = new S2::TokenPunct "%";
$NOT    = new S2::TokenPunct "!";
$DOT    = new S2::TokenPunct ".";
$DOTDOT = new S2::TokenPunct "..";
$LBRACE = new S2::TokenPunct "{";
$RBRACE = new S2::TokenPunct "}";
$LBRACK = new S2::TokenPunct "[";
$RBRACK = new S2::TokenPunct "]";
$LPAREN = new S2::TokenPunct "(";
$RPAREN = new S2::TokenPunct ")";
$COMMA  = new S2::TokenPunct ",";
$QMARK  = new S2::TokenPunct "?";
$DOLLAR = new S2::TokenPunct '$';
$HASSOC = new S2::TokenPunct "=>";

sub new
{
    my ($class, $punct) = @_;
    my $this = { 'punct' => $punct };
    bless $this, $class;
}

sub scan
{
    my ($class, $t) = @_;  # t = Tokenizer
    my $pc = $t->peekChar();
    
    if ($pc eq '$') {
        $t->getChar();
        return $DOLLAR;
    }

    if ($pc eq '<') {
        $t->getChar();
        if ($t->peekChar() eq '=') {
            $t->getChar();
            return $LTE;
        } else {
            return $LT;
        }
    }

    if ($pc eq '>') {
        $t->getChar();
        if ($t->peekChar() eq '=') {
            $t->getChar();
            return $GTE;
        } else {
            return $GT;
        }
    }

    if ($pc eq '=') {
        $t->getChar();
        if ($t->peekChar() eq '=') {
            $t->getChar();
            return $EQ;
        } elsif ($t->peekChar() eq '>') {
            $t->getChar();
            return $HASSOC;
        } else {
            return $ASSIGN;
        }
    }

    if ($pc eq '+') {
        $t->getChar();
        if ($t->peekChar() eq '+') {
            $t->getChar();
            return $INCR;
        } else {
            return $PLUS;
        }
    }

    if ($pc eq '+') {
        $t->getChar();
        if ($t->peekChar() eq '+') {
            $t->getChar();
            return $INCR;
        } else {
            return $PLUS;
        }
    }

    if ($pc eq '-') {
        $t->getChar();
        if ($t->peekChar() eq '-') {
            $t->getChar();
            return $DEC;
        } elsif ($t->peekChar() eq '>') {
            $t->getChar();
            return $DEREF;
        } else {
            return $MINUS;
        }
    }
    
    if ($pc eq ';') {
        $t->getChar();
        return $SCOLON;
    }

    if ($pc eq ':') {
        $t->getChar();
        if ($t->peekChar() eq ':') {
            $t->getChar();
            return $DCOLON;
        } else {
            return $COLON;
        }
    }

    if ($pc eq '&') {
        $t->getChar();
        if ($t->peekChar() eq '&') {
            $t->getChar();
            return $LOGAND;
        } else {
            return $BITAND;
        }
    }

    if ($pc eq '|') {
        $t->getChar();
        if ($t->peekChar() eq '|') {
            $t->getChar();
            return $LOGOR;
        } else {
            return $BITOR;
        }
    }

    if ($pc eq '*') {
        $t->getChar();
        return $MULT;
    }

    if ($pc eq '/') {
        $t->getChar();
        return $DIV;
    }

    if ($pc eq '%') {
        $t->getChar();
        return $MOD;
    }

    if ($pc eq '!') {
        $t->getChar();
        if ($t->peekChar() eq '=') {
            $t->getChar();
            return $NE;
        } else {
            return $NOT;
        }
    }

    if ($pc eq '{') {
        $t->getChar();
        return $LBRACE;
    }

    if ($pc eq '}') {
        $t->getChar();
        return $RBRACE;
    }

    if ($pc eq '[') {
        $t->getChar();
        return $LBRACK;
    }

    if ($pc eq ']') {
        $t->getChar();
        return $RBRACK;
    }

    if ($pc eq '(') {
        $t->getChar();
        return $LPAREN;
    }

    if ($pc eq ')') {
        $t->getChar();
        return $RPAREN;
    }

    if ($pc eq '.') {
        $t->getChar();
        if ($t->peekChar() eq '.') {
            $t->getChar();
            return $DOTDOT;
        } else {
            return $DOT;
        }
    }

    if ($pc eq ',') {
        $t->getChar();
        return $COMMA;
    }

    if ($pc eq '?') {
        $t->getChar();
        return $QMARK;
    }

    return undef;
}

sub getPunct { shift->{'punct'}; }

sub asHTML
{
    my ($this, $o) = @_;
    if ($this->{'punct'} =~ m![\[\]\(\)\{\}]!) {
        $o->write("<span class=\"b\">$this->{'punct'}</span>");
    } else {
        $o->write("<span class=\"p\">$this->{'punct'}</span>");
    }
}

sub asS2
{
    my ($this, $o) = @_;
    $o->write($this->{'punct'});
}

sub toString
{
    my $this = shift;
    "[TokenPunct] = $this->{'punct'}";
}

1;

