package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;
import java.util.Iterator;
import java.util.Hashtable;
import java.util.Enumeration;

public class NodeFunction extends Node
{
    TokenIdent classname;
    TokenIdent name;
    NodeType rettype;
    NodeFormals formals;
    NodeStmtBlock stmts;
    boolean builtin = false;
    boolean isCtor = false;
    Hashtable funcNums = null;
    
    Checker ck;

    String docstring;

    public String getDocString () {
        return docstring;
    }

    public static boolean canStart (Tokenizer toker) throws Exception
    {
	if (toker.peek().equals(TokenKeyword.FUNCTION))
	    return true;
	return false;
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	return parse(toker, false);
    }
    
    public static Node parse (Tokenizer toker,  boolean isDecl) throws Exception
    {
	NodeFunction n = new NodeFunction();

	// get the function keyword
	n.setStart(n.requireToken(toker, TokenKeyword.FUNCTION));

	// is the builtin keyword on?
	if (toker.peek().equals(TokenKeyword.BUILTIN)) {
	    n.builtin = true;
	    n.eatToken(toker);
	}

	// and the class name or function name (if no class)
	n.name = n.getIdent(toker);

	// check for a double colon
	if (toker.peek().equals(TokenPunct.DCOLON)) {
	    // so last ident was the class name
	    n.classname = n.name;
	    n.eatToken(toker);
	    n.name = n.getIdent(toker);
	} 

	// Argument list is optional.
	if (toker.peek().equals(TokenPunct.LPAREN)) {
	    n.addNode(n.formals = (NodeFormals) NodeFormals.parse(toker));
	}

	// return type is optional too.
	if (toker.peek().equals(TokenPunct.COLON)) {
	    n.requireToken(toker, TokenPunct.COLON);
	    n.addNode(n.rettype = (NodeType) NodeType.parse(toker));
	} 

        // docstring
        if (toker.peek() instanceof TokenStringLiteral) {
            TokenStringLiteral t = (TokenStringLiteral) n.eatToken(toker);
            n.docstring = t.getString();
        }
	
	// if inside a class declaration, only a declaration now.
	if (isDecl || n.builtin) {
	    n.requireToken(toker, TokenPunct.SCOLON);
	    return n;
	} 

	// otherwise, parsing the function definition.
	n.stmts = (NodeStmtBlock) NodeStmtBlock.parse(toker);
	n.addNode(n.stmts);
	
	return n;
    }

    public void check (Layer l, Checker ck) throws Exception
    {
	// keep a reference to the checker for later
	this.ck = ck;

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

	    if (formals != null) 
		formals.populateScope(stmts);
	    
	    ck.setCurrentFunctionClass(cname);   // for $.member lookups
	    ck.pushLocalBlock(stmts);
	    stmts.check(l, ck);
	    ck.popLocalBlock();
	}

	// remember the funcID -> local funcNum mappings for the backend
	funcNums = ck.getFuncNums();
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

    public NodeFormals getFormals () {
	return formals;
    }

    public String getName () {
	return name.getIdent();
    }

    public Type getReturnType () {
    	return (rettype != null ? rettype.getType() : Type.VOID);
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


    public void asPerl (BackendPerl bp, Indenter o) 
    {
        if (classname == null) {
            o.tabwrite("register_global_function(" +
                       bp.getLayerIDString() + "," +
                       bp.quoteString(name.getIdent() + (formals != null ? formals.toString() : "()")) + "," +
                       bp.quoteString(getReturnType().toString()));
            if (docstring != null)
                o.write(", " + bp.quoteString(docstring));
            o.writeln(");");
        }

        if (builtin) return;

	o.tabwrite("register_function(" + bp.getLayerIDString() +
		   ", [");

	// declare all the names by which this function would be called:
	// its base name, then all derivative classes which aren't already
	// used.
	Iterator i = ck.getFuncIDsIter(this);
	while (i.hasNext()) {
	    String funcID = (String) i.next();
	    o.write(bp.quoteString(funcID) + ", ");	    
	}

	o.writeln("], sub {");
	o.tabIn();

	// the first time register_function is run, it'll find the
	// funcNums for this session and save those in a hash and then
	// return the sub which is a closure and will have fast access
	// to that num -> num hash.  (benchmarking showed two
	// hashlookups on ints was faster than one on strings)

	if (funcNums.size() > 0) {
	    o.tabwriteln("my %_l2g_func = (");
	    o.tabIn();
	    Enumeration en = funcNums.keys();
	    while (en.hasMoreElements()) {
		String id = (String) en.nextElement();
		Integer num = (Integer) funcNums.get(id);
		o.tabwriteln(num + " => " + "get_func_num(" +
			     BackendPerl.quoteString(id) + "),");
	    }
	    o.tabOut();
	    o.tabwriteln(");");
	}

	// now, return the closure
	o.tabwriteln("return sub {");
	o.tabIn();
	
	// setup function argument/ locals
	o.tabwrite("my ($_ctx");
	if (classname != null && ! isCtor) {
	    o.write(", $this");
	}
	if (formals != null) {
	    ListIterator li = formals.iterator();
	    while (li.hasNext()) {
		NodeNamedType nt = (NodeNamedType) li.next();
		o.write(", $"+nt.getName());
	    }
	}
	o.writeln(") = @_;");
	// end function locals

	stmts.asPerl(bp, o, false);
	o.tabOut();
	o.tabwriteln("};");

	// end the outer sub
	o.tabOut();
	o.tabwriteln("});");
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

};
