package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;
import java.util.Hashtable;
import java.util.NoSuchElementException;

public class NodeStmtBlock extends Node
{
    protected LinkedList stmtlist = new LinkedList ();
    protected Type returnType;

    protected Hashtable localvars = new Hashtable (); // String -> Type

    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeStmtBlock ns = new NodeStmtBlock();
	ns.setStart(ns.requireToken(toker, TokenPunct.LBRACE));        
	boolean loop = true;
	boolean closed = false;

	do {
	    ns.skipWhite(toker);
	    Token p = toker.peek();

	    if (p == null) {
		loop = false;
	    } else if (p.equals(TokenPunct.RBRACE)) { 
		ns.eatToken(toker); 
		loop = false; 
		closed = true;
		
	    }
	    else if (NodeStmt.canStart(toker)) {
		Node s = NodeStmt.parse(toker);
		ns.stmtlist.add(s);
		ns.addNode(s);
	    }
	    else {
		throw new Exception("Unexpected token at " + toker.locationString() + 
				    " while parsing statement block: " + p.toString());
	    }

	} 
	while (loop);

	if (! closed)
	    throw new Exception("Didn't find closing brace in statement block");

	return ns;
    }

    public void addLocalVar (String v, Type t) {
	localvars.put(v, t);
    }
    public Type getLocalVar (String v) {
	return (Type) localvars.get(v);
    }

    public void setReturnType (Type t) {
	returnType = t;
    }

    public boolean willReturn () 
    {
	Node ns;

	// find the last statement in the block, if one exists
	try { 
	    ns = (Node) stmtlist.getLast();
	} catch (NoSuchElementException e) {
	    return false;
	}

	if (ns instanceof NodeReturnStmt) {
	    // a return statement obviously returns
	    return true;
	} else if (ns instanceof NodeIfStmt) {
	    // and if statement at the end of a function returns
	    // if all paths return, so ask the ifstatement
	    NodeIfStmt ni = (NodeIfStmt) ns;
	    return ni.willReturn();
	} else {
	    // all other types of statements don't return
	    return false;
	}

    }

    public void check (Layer l, Checker ck) throws Exception
    {
	ListIterator li = stmtlist.listIterator();

	// set the return type for any returnstmts that need it.
	// NOTE: the returnType is non-null if and only if it's
	// attached to a function.
	if (returnType != null) {
	    ck.setReturnType(returnType);
	}

	while (li.hasNext()) {
	    Node ns = (Node) li.next();
	    ns.check(l, ck);

	    if (! li.hasNext() && 
		returnType != null &&
		! returnType.equals(Type.VOID) &&
		! willReturn()) {
		throw new Exception("Statement block at "+getFilePos()+
				    " isn't guaranteed to return type "+
				    returnType);
	    } 
	}
    }
 
    public void asS2 (Indenter o) {
	o.writeln("{");
	o.tabIn();
	ListIterator li = stmtlist.listIterator();
	while (li.hasNext()) {
	    Node ns = (Node) li.next();
	    ns.asS2(o);    
	}
	o.tabOut();
	o.tabwrite("}");
    }

    public void asPerl (BackendPerl bp, Indenter o) 
    {
	asPerl(bp, o, true);
    }

    public void asPerl (BackendPerl bp, Indenter o, boolean doCurlies) 
    {
	if (doCurlies) {
	    o.writeln("{");
	    o.tabIn();
	}

	ListIterator li = stmtlist.listIterator();
	while (li.hasNext()) {
	    Node n = (Node) li.next();
	    n.asPerl(bp, o);
	}

	if (doCurlies) {
	    o.tabOut();
	    o.tabwrite("}");
	}
    }

};
