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
    $this->{'ck'} = $ck;
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
            $o->tabwriteln("get_func_num(" +
                           $bp->quoteString($id) + "),");
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
        $o->write(", $this");
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



__END__


    public void check (Layer l, Checker ck) throws Exception
    {
	// keep a reference to the checker for later
	this.ck = ck;
        ck.setInFunction(true);

	// reset the functionID -> local funcNum mappings
	ck.resetFunctionNums();

	// only core and layout layers can define functions
	if (! l.isCoreOrLayout()) {
	    throw new Exception("Only core and layout layers can define new functions.");
	}

	// tell the checker we've seen a function now so it knows
	// later to complain if it then sees a new class declaration.
	// (builtin functions are okay)
	if (! builtin) 
	    ck.setHitFunction(true);    

	String cname = className();
	String funcID = Checker.functionID(cname, name.getIdent(), formals);
	Type t = getReturnType();

	if (cname != null && cname.equals(name.getIdent())) {
	    isCtor = true;
	}

	// if this function is global, no declaration is done, but if
	// this is class-scoped, we must check the class exists and
	// that it declares this function.
	if (cname != null) {
	    NodeClass nc = ck.getClass(cname);
	    if (nc == null) {
		throw new Exception("Can't declare function "+funcID+" for "+
				    "non-existent class '"+cname+"' at "+
				    getFilePos());
	    }

	    Type et = ck.functionType(funcID);
	    if (et == null) {
		throw new Exception("Can't define undeclared object function "+funcID+" at "+
				    getFilePos());
	    }

	    // find & register all the derivative names by which this function
	    // could be called.
	    ListIterator li = nc.getDerClasses().listIterator();
	    while (li.hasNext()) {
		DerItem dc = (DerItem) li.next();
		NodeClass c = dc.nc;
		
		ListIterator fi = NodeFormals.variationIterator(formals, ck);
		while (fi.hasNext()) {
		    NodeFormals fv = (NodeFormals) fi.next();
		    String derFuncID = Checker.functionID(c.getName(), getName(), fv);
		    ck.setFuncDistance(derFuncID, new DerItem(this, dc.dist));
		    ck.addFunction(derFuncID, t, builtin);
		}
	    }
	} else {
	    // non-class function.  register all variations of the formals.
	    ListIterator fi = NodeFormals.variationIterator(formals, ck);
	    while (fi.hasNext()) {
		NodeFormals fv = (NodeFormals) fi.next();
		String derFuncID = Checker.functionID(cname, getName(), fv);
		ck.setFuncDistance(derFuncID, new DerItem(this, 0));
		ck.addFunction(derFuncID, t, builtin);
	    }
	}
	
	// check the formals
	if (formals != null) 
	    formals.check(l, ck);
	
	// check the statement block
	if (stmts != null) {
	    // prepare stmts to be checked
	    stmts.setReturnType(t);

	    // make sure $this is accessible in a class method
	    // FIXME: not in static functions, once we have static functions
	    if (cname != null) {
		stmts.addLocalVar("this", new Type(cname));
	    } else {
		stmts.addLocalVar("this", Type.VOID);  // prevent its use
	    }

            // make sure $this is accessible in a class method 
            // that has a parent.
            String pname = ck.getParentClassName(cname);
            if (pname != null) {
		stmts.addLocalVar("super", new Type(pname));
	    } else {
		stmts.addLocalVar("super", Type.VOID);  // prevent its use
            }

	    if (formals != null) 
		formals.populateScope(stmts);
	    
	    ck.setCurrentFunctionClass(cname);   // for $.member lookups
	    ck.pushLocalBlock(stmts);
	    stmts.check(l, ck);
	    ck.popLocalBlock();
	}

	// remember the funcID -> local funcNum mappings for the backend
	funcNames = ck.getFuncNames();
    }

    // called by NodeClass
    public void registerFunction (Checker ck, String cname)
	throws Exception
    {
	String funcID = Checker.functionID(cname, getName(), formals);
	Type et = ck.functionType(funcID);
	Type rt = getReturnType();

	// check that function is either currently undefined or 
	// defined with the same type, otherwise complain
	if (et == null || et.equals(rt)) {
	    ck.addFunction(funcID, rt, builtin);  // Register
	} else {
	    throw new Exception("Can't redefine function '"+getName()+"' with return "+
				"type of '"+rt+"' at "+getFilePos()+" masking "+
				"earlier definition of type '"+et+"'.");
	}
    }

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



    public String toString ()
    {
	return (className() + "...");
    }

    public boolean isBuiltin () {
	return builtin;
    }

    //-----------------------------

    private String className () 
    {
	if (classname != null)
	    return classname.getIdent();
	return null;
    }

    private String totalName ()
    {
	StringBuffer sb = new StringBuffer(50);

	String clas = className(); 
	if (clas != null) {
	    sb.append(clas);
	    sb.append("::");
	}
	sb.append(name.getIdent());

	return sb.toString();
    }
