#!/usr/bin/perl
#

package S2::NodeTerm;

use strict;
use S2::Node;
use S2::NodeExpr;
use S2::NodeArrayLiteral;
use S2::NodeArguments;

use vars qw($VERSION @ISA
            $INTEGER $STRING $BOOL $VARREF $SUBEXPR
            $DEFINEDTEST $SIZEFUNC $REVERSEFUNC $ISNULLFUNC
            $NEW $NEWNULL $FUNCCALL $METHCALL $ARRAY);

$VERSION = '1.0';
@ISA = qw(S2::NodeExpr);

$INTEGER = 1;
$STRING = 2;
$BOOL = 3;
$VARREF = 4;
$SUBEXPR = 5;
$DEFINEDTEST = 6;
$SIZEFUNC = 7;
$REVERSEFUNC = 8;
$ISNULLFUNC = 12;
$NEW = 9;
$NEWNULL = 13;
$FUNCCALL = 10;
$METHCALL = 11;
$ARRAY = 14;

sub new {
    my ($class, $n) = @_;
    my $node = new S2::NodeExpr;
    bless $node, $class;
}

sub canStart {
    my ($class, $toker) = @_;
    my $t = $toker->peek();

    return $t->isa('S2::TokenIntegerLiteral') ||
        $t->isa('S2::TokenStringLiteral') ||
        $t->isa('S2::TokenIdent') ||
        $t == $S2::TokenPunct::DOLLAR ||
        $t == $S2::TokenPunct::LPAREN ||
        $t == $S2::TokenPunct::LBRACK ||
        $t == $S2::TokenPunct::LBRACE ||
        $t == $S2::TokenKeyword::DEFINED ||
        $t == $S2::TokenKeyword::TRUE ||
        $t == $S2::TokenKeyword::FALSE ||
        $t == $S2::TokenKeyword::NEW ||
        $t == $S2::TokenKeyword::SIZE ||
        $t == $S2::TokenKeyword::REVERSE ||
        $t == $S2::TokenKeyword::ISNULL ||
        $t == $S2::TokenKeyword::NULL;
}

sub getType {
    my ($this, $ck, $wanted) = @_;
    my $type = $this->{'type'};

    if ($type == $INTEGER) { return $S2::Type::INT; }

    if ($type == $STRING) {
        return $this->{'nodeString'}->getType($ck, $S2::Type::STRING)
            if $this->{'nodeString'};
        if ($ck->isStringCtor($wanted)) {
            $this->{'ctorclass'} = $wanted->baseType();
            return $wanted;
        }
        return $S2::Type::STRING;
    }
    
    if ($type == $SUBEXPR) { return $this->{'subExpr'}->getType($ck, $wanted); }

    if ($type == $BOOL) { return $S2::Type::BOOL; }

    if ($type == $DEFINEDTEST) {
        print STDERR "FIXME: check type of defined expression\n";
        return $S2::Type::BOOL;
    }

    if ($type == $SIZEFUNC) {
        $this->{'subType'} = $this->{'subExpr'}->getType($ck);
        return $S2::Type::INT if
            $this->{'subType'}->isArrayOf() ||
            $this->{'subType'}->equals($S2::Type::STRING);
        die "Can't use size on expression that's not a string or array ".
            "at " . $this->getFilePos->toString . "\n";
    }

    if ($type == $REVERSEFUNC) {
        $this->{'subType'} = $this->{'subExpr'}->getType($ck);

        # reverse a string
        return $S2::Type::STRING if 
            $this->{'subType'}->equals($S2::Type::STRING);

        # reverse an array
        return $this->{'subType'} if
            $this->{'subType'}->isArrayOf();

        die "Can't reverse on expression that's not a string or array " .
            "at " . $this->getFilePos->toString . "\n";
    }

    if ($type == $ISNULLFUNC) {
        $this->{'subType'} = $this->{'subExpr'}->getType($ck);

        if ($this->{'subExpr'}->isa('S2::NodeTerm')) {
            my $nt = $this->{'subExpr'};
            if ($nt->{'type'} != $VARREF && $nt->{'type'} != $FUNCCALL &&
                $nt->{'type'} != $METHCALL) {
                die("isnull must only be used on an object variable, ".
                    "function call or method call at ".$this->getFilePos->toString . "\n");
            }
        } else {
            die("isnull must only be used on an object variable, ".
                "function call or method call at ".$this->getFilePos->toString . "\n");
        }

        # can't be used on arrays and hashes
        unless ($this->{'subType'}->isSimple()) {
            die("Can't use isnull on an array or hash at " . $this->getFilePos->toString . "\n");
        }
        
        # not primitive types either
        if ($this->{'subType'}->isPrimitive()) {
            die("Can't use isnull on primitive types at ".$this->getFilePos->toString . "\n");
        }
        
        # nor void
        if ($this->{'subType'}->equals($S2::Type::VOID)) {
            die("Can't use isnull on a void value at ".$this->getFilePos->toString . "\n");
        }
        
        return $S2::Type::BOOL;
    }

    if ($type == $NEW || $type == $NEWNULL) {
        my $clas = $this->{'newClass'}->getIdent();
        my $nc = $ck->getClass($clas);
        unless ($nc) {
            die("Can't instantiate unknown class at " .
                $this->getFilePos->toString . "\n");
        }
        return new S2::Type $clas;
    }

    if ($type == $VARREF) {
        unless ($ck->getInFunction()) {
            die "Can't reference a variable outside of a function at " .
                $this->getFilePos->toString . "\n";
        }
        return $this->{'var'}->getType($ck, $wanted);
    }

    if ($type == $METHCALL || $type == $FUNCCALL) {
        S2::error($this, "Can't call a function or method outside of a function")
            unless $ck->getInFunction();

        if ($type == $METHCALL) {
            my $vartype = $this->{'var'}->getType($ck, $wanted);
            S2::error($this, "Cannot call a method on an array or hash")
                unless $vartype->isSimple();

            $this->{'funcClass'} = $vartype->toString;
            
            my $methClass = $ck->getClass($this->{'funcClass'});
            S2::error($this, "Can't call a method on an instance of an undefined class")
                unless $methClass;
        }

          $this->{'funcID'} = 
              S2::Checker::functionID($this->{'funcClass'},
                                      $this->{'funcIdent'}->getIdent(),
                                      $this->{'funcArgs'}->typeList($ck));
          $this->{'funcBuiltin'} = $ck->isFuncBuiltin($this->{'funcID'});

          $this->{'funcID_noclass'} = 
              S2::Checker::functionID(undef,
                                      $this->{'funcIdent'}->getIdent(),
                                      $this->{'funcArgs'}->typeList($ck));
          
          my $t = $ck->functionType($this->{'funcID'});
          $this->{'funcNum'} = $ck->functionNum($this->{'funcID'})
              unless $this->{'funcBuiltin'};
          
          S2::error($this, "Unknown function $this->{'funcID'}")
              unless $t;
          
          return $t;
    }

    if ($type == $ARRAY) {
        return $this->{'subExpr'}->getType($ck, $wanted);
    }

    S2::error($this, "Unknown NodeTerm type");
}

sub isLValue {
    my $this = shift;
    return 1 if $this->{'type'} == $VARREF;
    return $this->{'subExpr'}->isLValue()
        if $this->{'type'} == $SUBEXPR;
    return 0;
}

sub makeAsString {
    my ($this, $ck) = @_;
    return 0 unless $this->{'type'} == $VARREF;

    my $t = $this->{'var'}->getType($ck);
    return 0 unless $t->isSimple();
    
    my $bt = $t->baseType;
    
    # class has .toString() method?
    if ($ck->classHasToString($bt)) {
        # let's change this VARREF into a METHCALL!
        # warning: ugly hacks ahead...
        $this->{'type'} = $METHCALL;
        $this->{'funcIdent'} = new S2::TokenIdent "toString";
        $this->{'funcClass'} = $bt;
        $this->{'funcArgs'} = new S2::NodeArguments; # empty
        $this->{'funcID_noclass'} = "toString()";
        $this->{'funcID'} = "${bt}::toString()";
        $this->{'funcBuiltin'} = $ck->isFuncBuiltin($this->{'funcID'});
        return 1;
    }

    # class has $.as_string string member?
    if ($ck->classHasAsString($bt)) {
        $this->{'var'}->useAsString();
        return 1;
    }
    
    return 0;    
}

sub parse {
    my ($class, $toker) = @_;
    my $nt = new S2::NodeTerm;
    my $t = $toker->peek();

    # integer literal
    if ($t->isa('S2::TokenIntegerLiteral')) {
        $nt->{'type'} = $INTEGER;
        $nt->{'tokInt'} = $nt->eatToken($toker);
        return $nt;
    }

    # boolean literal
    if ($t == $S2::TokenKeyword::TRUE ||
        $t == $S2::TokenKeyword::FALSE) {
        $nt->{'type'} = $BOOL;
        $nt->{'boolValue'} = $t == $S2::TokenKeyword::TRUE;
        $nt->eatToken($toker);
        return $nt;
    }

    # string literal
    if ($t->isa('S2::TokenStringLiteral')) {
        my $ts = $t;
        my $ql = $ts->getQuotesLeft();
        my $qr = $ts->getQuotesRight();

        if ($qr) {
            # whole string literal
            $nt->{'type'} = $STRING;
            $nt->{'tokStr'} = $nt->eatToken($toker);
            $nt->setStart($nt->{'tokStr'});
            return $nt;
        }

        # interpolated string literal (turn into a subexpr)
        my $toklist = [];
        
        $nt->{'type'} = $STRING;
        $nt->{'tokStr'} = $nt->eatToken($toker);
        push @$toklist, $nt->{'tokStr'}->clone();
        $nt->{'tokStr'}->setQuotesRight($ql);
        
        my $lhs = $nt;
        my $filepos = $nt->{'tokStr'}->getFilePos();
        
        my $loop = 1;
        while ($loop) {
            my $rhs = undef;
            my $tok = $toker->peek();
            if ($tok->isa('S2::TokenStringLiteral')) {
                $rhs = new S2::NodeTerm;
                $ts = $tok;
                $rhs->{'type'} = $STRING;
                $rhs->{'tokStr'} = $rhs->eatToken($toker);
                push @$toklist, $rhs->{'tokStr'}->clone();

                $loop = 0 if $ts->getQuotesRight() == $ql;
                $ts->setQuotesRight($ql);
                $ts->setQuotesLeft($ql);
            } elsif ($tok == $S2::TokenPunct::DOLLAR) {
                $rhs = parse S2::NodeTerm $toker;
                push @$toklist, $rhs;
            } else {
                S2::error($tok, "Error parsing interpolated string: " . $tok->toString);
            }
            
            # don't make a sum out of a blank string on either side
            my $join = 1;
            if ($lhs->isa('S2::NodeTerm')) {
                if ($lhs->{'type'} == $STRING &&
                    length($lhs->{'tokStr'}->getString()) == 0) {
                    $lhs = $rhs;
                    $join = 0;
                }
            }
            if ($rhs->isa('S2::NodeTerm')) {
                if ($rhs->{'type'} == $STRING &&
                    length($rhs->{'tokStr'}->getString()) == 0) {
                    $join = 0;
                }
            }

            if ($join) {
                $lhs = S2::NodeSum->new($lhs, $S2::TokenPunct::PLUS, $rhs);
            }
        }
        
        $lhs->setTokenList($toklist);
        $lhs->setStart($filepos);
        
        my $rnt = new S2::NodeTerm;
        $rnt->{'type'} = $STRING;
        $rnt->{'nodeString'} = $lhs;
        $rnt->addNode($lhs);
        return $rnt;
    }
    
    # Sub-expression (in parenthesis)
    if ($t == $S2::TokenPunct::LPAREN) {
        $nt->{'type'} = $SUBEXPR;
        $nt->setStart($nt->eatToken($toker));

        $nt->{'subExpr'} = parse S2::NodeExpr $toker;
        $nt->addNode($nt->{'subExpr'});

        $nt->requireToken($toker, $S2::TokenPunct::RPAREN);
        return $nt;
    }

    # defined test
    if ($t == $S2::TokenKeyword::DEFINED) {
        $nt->{'type'} = $DEFINEDTEST;
        $nt->eatToken($toker);
        $nt->{'subExpr'} = parse S2::NodeTerm $toker;
        $nt->addNode($nt->{'subExpr'});
        return $nt;
    }

    # reverse function
    if ($t == $S2::TokenKeyword::REVERSE) {
        $nt->{'type'} = $REVERSEFUNC;
        $nt->eatToken($toker);
        $nt->{'subExpr'} = parse S2::NodeTerm $toker;
        $nt->addNode($nt->{'subExpr'});
        return $nt;
    }

    # size function
    if ($t == $S2::TokenKeyword::SIZE) {
        $nt->{'type'} = $SIZEFUNC;
        $nt->eatToken($toker);
        $nt->{'subExpr'} = parse S2::NodeTerm $toker;
        $nt->addNode($nt->{'subExpr'});
        return $nt;
    }

    # isnull function
    if ($t == $S2::TokenKeyword::ISNULL) {
        $nt->{'type'} = $ISNULLFUNC;
        $nt->eatToken($toker);
        $nt->{'subExpr'} = parse S2::NodeTerm $toker;
        $nt->addNode($nt->{'subExpr'});
        return $nt;
    }

    # new andnull
    if ($t == $S2::TokenKeyword::NEW ||
        $t == $S2::TokenKeyword::NULL) {
        $nt->{'type'} = $t == $S2::TokenKeyword::NEW ? $NEW : $NEWNULL;
        $nt->eatToken($toker);
        $nt->{'newClass'} = $nt->getIdent($toker);
        return $nt;
    }

    # VarRef
    if ($t == $S2::TokenPunct::DOLLAR) {
        $nt->{'type'} = $VARREF;
        $nt->{'var'} = parse S2::NodeVarRef $toker;
        $nt->addNode($nt->{'var'});

        # check for -> after, like: $object->method(arg1, arg2, ...)
        if ($toker->peek() == $S2::TokenPunct::DEREF) {
            $nt->{'derefLine'} = $toker->peek()->getFilePos()->{'line'};
            $nt->eatToken($toker);
            $nt->{'type'} = $METHCALL;
            # don't return... parsing continues below.
        } else {
            return $nt;
        }
    }

    # function/method call
    if ($nt->{'type'} == $METHCALL || $t->isa('S2::TokenIdent')) {
        $nt->{'type'} = $FUNCCALL unless $nt->{'type'} == $METHCALL;
        $nt->{'funcIdent'} = $nt->getIdent($toker);
        $nt->{'funcArgs'} = parse S2::NodeArguments $toker;
        $nt->addNode($nt->{'funcArgs'});
        return $nt;
    }

    # array/hash literal
    if (S2::NodeArrayLiteral->canStart($toker)) {
        $nt->{'type'} = $ARRAY;
        $nt->{'subExpr'} = parse S2::NodeArrayLiteral $toker;
        $nt->addNode($nt->{'subExpr'});
        return $nt;
    }
    
    S2::error($toker->peek(), "Can't finish parsing NodeTerm");
}


sub asS2 {
    my ($this, $o) = @_;
    die "NodeTerm::asS2(): not implemented";
}

sub asPerl {
    my ($this, $bp, $o) = @_;
    my $type = $this->{'type'};

    if ($type == $INTEGER) {
        $this->{'tokInt'}->asPerl($bp, $o);
        return;
    }

    if ($type == $STRING) {
        if (defined $this->{'nodeString'}) {
            $o->write("(");
            $this->{'nodeString'}->asPerl($bp, $o);
            $o->write(")");
            return;
        }
        if ($this->{'ctorclass'}) {
            $o->write("S2::Builtin::$this->{'ctorclass'}__$this->{'ctorclass'}(");
        }
        $this->{'tokStr'}->asPerl($bp, $o);
        $o->write(")") if $this->{'ctorclass'};
        return;
    }

    if ($type == $BOOL) {
        $o->write($this->{'boolValue'} ? "1" : "0");
        return;
    }

    if ($type == $SUBEXPR) {
        $o->write("(");
        $this->{'subExpr'}->asPerl($bp, $o);
        $o->write(")");
        return;
    }

    if ($type == $ARRAY) {
        $this->{'subExpr'}->asPerl($bp, $o);
        return;
    }

    if ($type == $NEW) {
        $o->write("{'_type'=>" .
                  $bp->quoteString($this->{'newClass'}->getIdent()) .
                  "}");
        return;
    }

    if ($type == $NEWNULL) {
        $o->write("{'_type'=>" .
                  $bp->quoteString($this->{'newClass'}->getIdent()) .
                  ", '_isnull'=>1}}");
        return;
    }

    # FIXME: defined vs. null?  should have opposite semantics?
    # really, what does defined() mean for S2?  perl implementation
    # is to use hashes even for null values.  stupid.
    if ($type == $DEFINEDTEST) {
        $o->write("defined(");
        $this->{'subExpr'}->asPerl($bp, $o);
        $o->write(")");
        return;
    }

    if ($type == $REVERSEFUNC) {
        if ($this->{'subType'}->isArrayOf()) {
            $o->write("[reverse(@{");
            $this->{'subExpr'}->asPerl($bp, $o);
            $o->write("})]");
        } elsif ($this->{'subType'}->equals($S2::Type::STRING)) {
            $o->write("reverse(");
            $this->{'subExpr'}->asPerl($bp, $o);
            $o->write(")");
        }
        return;
    }

    if ($type == $SIZEFUNC) {
        if ($this->{'subType'}->isArrayOf()) {
            $o->write("scalar(\@{");
            $this->{'subExpr'}->asPerl($bp, $o);
            $o->write("})");
        } elsif ($this->{'subType'}->equals($S2::Type::STRING)) {
            $o->write("length(");
            $this->{'subExpr'}->asPerl($bp, $o);
            $o->write(")");
        }
        return;
    }

    if ($type == $ISNULLFUNC) {
        $o->write("(ref ");
        $this->{'subExpr'}->asPerl($bp, $o);
        $o->write(" ne \"HASH\" || ");
        $this->{'subExpr'}->asPerl($bp, $o);
        $o->write("->{'_isnull'})");
        return;
    }

    if ($type == $VARREF) {
        $this->{'var'}->asPerl($bp, $o);
        return;
    }

    if ($type == $FUNCCALL || $type == $METHCALL) {

        # builtin functions can be optimized.
        if ($this->{'funcBuiltin'}) {
            # these built-in functions can be inlined.
            if ($this->{'funcID'} eq "string(int)") {
                $this->{'funcArgs'}->asPerl($bp, $o, 0);
                return;
            }
            if ($this->{'funcID'} eq "int(string)") {
                # cast from string to int by adding zero to it
                $o->write("int(");
                $this->{'funcArgs'}->asPerl($bp, $o, 0);
                $o->write(")");
                return;
            }

            # otherwise, call the builtin function (avoid a layer
            # of indirection), unless it's for a class that has
            # children (won't know until run-time which class to call)

            $o->write("S2::Builtin::");
            if ($this->{'funcClass'}) {
                $o->write("$this->{'funcClass'}__");
            }
            $o->write($this->{'funcIdent'}->getIdent());
        } else {
            if ($type == $METHCALL && $this->{'funcClass'} ne "string") {
                $o->write("\$_ctx->[VTABLE]->{get_object_func_num(");
                $o->write($bp->quoteString($this->{'funcClass'}));
                $o->write(",");
                $this->{'var'}->asPerl($bp, $o);
                $o->write(",");
                $o->write($bp->quoteString($this->{'funcID_noclass'}));
                $o->write(",");
                $o->write($bp->getLayerID());
                $o->write(",");
                $o->write($this->{'derefLine'}+0);
                if ($this->{'var'}->isSuper()) {
                    $o->write(",1");
                }
                $o->write(")}->");
            } elsif ($type == $METHCALL) {
                $o->write("\$_ctx->[VTABLE]->{get_func_num(");
                $o->write($bp->quoteString($this->{'funcID'}));
                $o->write(")}->");
            } else {
                $o->write("\$_ctx->[VTABLE]->{\$_l2g_func[$this->{'funcNum'}]}->");
            }
        }

        $o->write("(\$_ctx, ");
        
        # this pointer
        if ($type == $METHCALL) {
            $this->{'var'}->asPerl($bp, $o);
            $o->write(", ");
        }
        
        $this->{'funcArgs'}->asPerl($bp, $o, 0);
        
        $o->write(")");
        return;
    }

    die "Unknown term type";
}


