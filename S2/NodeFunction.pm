#!/usr/bin/perl
#

package S2::NodeFunction;

use strict;
use S2::Node;
use S2::NodeFormals;
use S2::NodeStmtBlock;
use vars qw($VERSION @ISA);

$VERSION = '1.0';
@ISA = qw(S2::Node);

sub new {
    my ($class) = @_;
    my $node = new S2::Node;
    bless $node, $class;
}

sub getDocString { shift->{'docstring'}; }

sub canStart {
    my ($class, $toker) = @_;
    return $toker->peek() == $S2::TokenKeyword::FUNCTION;
}

sub parse {
    my ($class, $toker, $isDecl) = @_;
    my $n = new S2::NodeFunction;

    # get the function keyword
    $n->setStart($n->requireToken($toker, $S2::TokenKeyword::FUNCTION));

    # is the builtin keyword on?
    if ($toker->peek() == $S2::TokenKeyword::BUILTIN) {
        $n->{'builtin'} = 1;
        $n->eatToken($toker);
    }

    # the class name or function name (if no class)
    $n->{'name'} = $n->getIdent($toker);

    # check for a double colon
    if ($toker->peek() == $S2::TokenPunct::DCOLON) {
        # so last ident was the class name
        $n->{'classname'} = $n->{'name'};
        $n->eatToken($toker);
        $n->{'name'} = $n->getIdent($toker);
    }

    # Argument list is optional.
    if ($toker->peek() == $S2::TokenPunct::LPAREN) {
        $n->addNode($n->{'formals'} = S2::NodeFormals->parse($toker));
    }

    # return type is optional too.
    if ($toker->peek() == $S2::TokenPunct::COLON) {
        $n->requireToken($toker, $S2::TokenPunct::COLON);
        $n->addNode($n->{'rettype'} = S2::NodeType->parse($toker));
    }

    # docstring
    if ($toker->peek()->isa('S2::TokenStringLiteral')) {
        $n->{'docstring'} = $n->eatToken($toker)->getString();
    }

    # if inside a class declaration, only a declaration now.
    if ($isDecl || $n->{'builtin'}) {
        $n->requireToken($toker, $S2::TokenPunct::SCOLON);
        return $n;
    }
    
    # otherwise, keep parsing the function definition.
    $n->{'stmts'} = parse S2::NodeStmtBlock $toker;
    $n->addNode($n->{'stmts'});

    return $n;
}

sub getFormals { shift->{'formals'}; }
sub getName { shift->{'name'}->getIdent(); }
sub getReturnType { 
    my $this = shift;
    return $this->{'rettype'} ? $this->{'rettype'}->getType() : $S2::Type::VOID;
}

sub check {
    my ($this, $l, $ck) = @_;

    # keep a reference to the checker for later
    $this->{'ck'} = $ck;
    $ck->setInFunction(1);

    # reset the functionID -> local funcNum mappings
    $ck->resetFunctionNums();

    # only core and layout layers can define functions
    S2::error($this, "Only core and layout layers can define new functions.")
        unless $l->isCoreOrLayout();
    
    # tell the checker we've seen a function now so it knows
    # later to complain if it then sees a new class declaration.
    # (builtin functions are okay)
    $ck->setHitFunction(1) unless $this->{'builtin'};
    
    my $cname = $this->className();
    my $funcID = S2::Checker::functionID($cname, $this->{'name'}->getIdent(), $this->{'formals'});
    my $t = $this->getReturnType();

    if ($cname && $cname eq $this->{'name'}->getIdent()) {
        $this->{'isCtor'} = 1;
    }

    # if this function is global, no declaration is done, but if
    # this is class-scoped, we must check the class exists and
    # that it declares this function.
    if ($cname) {
        my $nc = $ck->getClass($cname);
        unless ($nc) {
            S2::error($this, "Can't declare function $funcID for ".
                      "non-existent class '$cname'");
        }

        my $et = $ck->functionType($funcID);
        unless ($et) {
            S2::error($this, "Can't define undeclared object function $funcID");
        }

        # find & register all the derivative names by which this function
        # could be called.
        my $dercs = $nc->getDerClasses();
        my $fvs = S2::NodeFormals::variations($this->{'formals'}, $ck);
        foreach my $dc (@$dercs) {  # DerItem
            my $c = $dc->{'nc'}; # NodeClass
            foreach my $fv (@$fvs) {
                my $derFuncID = S2::Checker::functionID($c->getName(), $this->getName(), $fv);
                $ck->setFuncDistance($derFuncID, { 'nf' => $this, 'dist' => $dc->{'dist'} });
                $ck->addFunction($derFuncID, $t, $this->{'builtin'});
            }
        }
    } else {
        # non-class function.  register all variations of the formals.
        my $fvs = S2::NodeFormals::variations($this->{'formals'}, $ck);
        foreach my $fv (@$fvs) {
            my $derFuncID = S2::Checker::functionID($cname, 
                                                    $this->getName(), 
                                                    $fv);
            $ck->setFuncDistance($derFuncID, { 'nf' => $this, 'dist' => 0 });
            $ck->addFunction($derFuncID, $t, $this->{'builtin'});
        }
    }
	
    # check the formals
    $this->{'formals'}->check($l, $ck) if $this->{'formals'};

    
    # check the statement block
    if ($this->{'stmts'}) {
        # prepare stmts to be checked
        $this->{'stmts'}->setReturnType($t);
        
        # make sure $this is accessible in a class method
        # FIXME: not in static functions, once we have static functions
        if ($cname) {
            $this->{'stmts'}->addLocalVar("this", new S2::Type($cname));
        } else {
            $this->{'stmts'}->addLocalVar("this", $S2::Type::VOID);  # prevent its use
        }
        
        # make sure $this is accessible in a class method 
        # that has a parent.
        my $pname = $ck->getParentClassName($cname); # String
        if (defined $pname) {
            $this->{'stmts'}->addLocalVar("super", new S2::Type($pname));
        } else {
            $this->{'stmts'}->addLocalVar("super", $S2::Type::VOID);  # prevent its use
        }
        
        $this->{'formals'}->populateScope($this->{'stmts'}) if $this->{'formals'};
        
        $ck->setCurrentFunctionClass($cname);   # for $.member lookups
        $ck->pushLocalBlock($this->{'stmts'});
        $this->{'stmts'}->check($l, $ck);
        $ck->popLocalBlock();
    }

    # remember the funcID -> local funcNum mappings for the backend
    $this->{'funcNames'} = $ck->getFuncNames();
    
}

sub asS2 {
    my ($this, $o) = @_;
    die "not done";
}

sub asPerl {
    my ($this, $bp, $o) = @_;
    unless ($this->{'classname'}) {
        $o->tabwrite("register_global_function(" .
                     $bp->getLayerIDString() . "," .
                     $bp->quoteString($this->{'name'}->getIdent() . ($this->{'formals'} ? $this->{'formals'}->toString() : "()")) . "," .
                     $bp->quoteString($this->getReturnType()->toString()));
        if ($this->{'docstring'}) {
            $o->write(", " . $bp->quoteString($this->{'docstring'}));
        }
        $o->writeln(");");
    }

    return if $this->{'builtin'};

    $o->tabwrite("register_function(" . $bp->getLayerIDString() .
                 ", [");

    # declare all the names by which this function would be called:
    # its base name, then all derivative classes which aren't already
    # used.
    foreach my $funcID (@{$this->{'ck'}->getFuncIDs($this)}) {
        $o->write($bp->quoteString($funcID) . ", ");
    }
     
    $o->writeln("], sub {");
    $o->tabIn();

    # the first time register_function is run, it'll find the
    # funcNames for this session and save those in a list and then
    # return the sub which is a closure and will have fast access
    # to that num -> num hash.  (benchmarking showed two
    # hashlookups on ints was faster than one on strings)

    if (scalar(@{$this->{'funcNames'}})) {
        $o->tabwriteln("my \@_l2g_func = ( undef, ");
        $o->tabIn();
        foreach my $id (@{$this->{'funcNames'}}) {
            $o->tabwriteln("get_func_num(" .
                           $bp->quoteString($id) . "),");
        }
        $o->tabOut();
        $o->tabwriteln(");");
    }

    # now, return the closure
    $o->tabwriteln("return sub {");
    $o->tabIn();
	
    # setup function argument/ locals
    $o->tabwrite("my (\$_ctx");
    if ($this->{'classname'} && ! $this->{'isCtor'}) {
        $o->write(", \$this");
    }

    if ($this->{'formals'}) {
        my $nts = $this->{'formals'}->getFormals();
        foreach my $nt (@$nts) {
            $o->write(", \$" . $nt->getName());
        }
    }

    $o->writeln(") = \@_;");
    # end function locals
    
    $this->{'stmts'}->asPerl($bp, $o, 0);
    $o->tabOut();
    $o->tabwriteln("};");
    
    # end the outer sub
    $o->tabOut();
    $o->tabwriteln("});");
}

sub toString {
    my $this = shift;
    return $this->className() . "...";
}

sub isBuiltin { shift->{'builtin'}; }

# private
sub className {
    my $this = shift;
    return undef unless $this->{'classname'};
    return $this->{'classname'}->getIdent();
        
}

# private
sub totalName {
    my $this = shift;
    my $sb;
    my $clas = $this->className();
    $sb .= "${clas}::" if $clas;
    $sb .= $this->{'name'}->getIdent();
    return $sb;
}

# called by NodeClass
sub registerFunction {
    my ($this, $ck, $cname) = @_;

    my $fname = $this->getName();
    my $funcID = S2::Checker::functionID($cname, $fname,
                                         $this->{'formals'});
    my $et = $ck->functionType($funcID);
    my $rt = $this->getReturnType();

    # check that function is either currently undefined or 
    # defined with the same type, otherwise complain
    if ($et && ! $et->equals($rt)) {
        S2::error($this, "Can't redefine function '$fname' with return ".
                  "type of '" . $rt->toString . "' masking ".
                  "earlier definition of type '". $et->toString ."'.");
    }

    $ck->addFunction($funcID, $rt, $this->{'builtin'});  # Register
}

__END__


    public void asS2 (Indenter o) 
    {
	o.tabwrite("function " + totalName());
	if (formals != null) {
	    o.write(" ");
	    formals.asS2(o);
	}
	if (rettype != null) {
	    o.write(" : ");
	    rettype.asS2(o);
	}
	if (stmts != null) {
	    o.write(" ");
	    stmts.asS2(o);
	    o.newline();
	} else {
	    o.writeln(";");
	}
    }



