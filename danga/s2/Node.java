package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;

public abstract class Node
{
    protected FilePos startPos;
    protected LinkedList tokenlist = new LinkedList ();
    
    public void setStart (Token t) {
	startPos = (FilePos) t.getFilePos().clone();
    }

    public void setStart (FilePos p) {
	startPos = (FilePos) p.clone();
    }

    public void check (Layer l, Checker ck) throws Exception {
	System.err.println("FIXME: check not implemented for " + this.toString());
    }
    
    public void asHTML (Output o) {
	ListIterator li = tokenlist.listIterator(0);
	while (li.hasNext()) {
	    Object el = li.next();
	    if (el instanceof Token) {
		Token t = (Token) el;
		t.asHTML(o);
	    } else if (el instanceof Node) {
		Node n = (Node) el;
		n.asHTML(o);
	    }
	}
    }

    public void asS2 (Indenter o) {
	o.tabwriteln("###Node::asS2###");
	return;
    }

    public void asPerl (BackendPerl bp, Indenter o) {
	o.tabwriteln("###"+this+"::asPerl###");
	
	/*
	ListIterator li = tokenlist.listIterator(0);
	while (li.hasNext()) {
	    Object el = li.next();
	    if (el instanceof Token) {
		Token t = (Token) el;
		t.asPerl(o);
	    } else if (el instanceof Node) {
		Node n = (Node) el;
		n.asPerl(o);
	    }
	}
	*/
    }

    public void setTokenList (LinkedList newlist) {
	tokenlist = newlist;
    }

    public void addNode (Node subnode) {
	tokenlist.add(subnode);
    }

    public void addToken (Token t) {
	tokenlist.add(t);
    }

    public Token eatToken (Tokenizer toker, boolean ignoreSpace) throws Exception {
	Token t = toker.getToken();
	tokenlist.add(t);
	if (ignoreSpace) skipWhite(toker);
	return t;
    }

    public Token eatToken (Tokenizer toker) throws Exception {
	return eatToken(toker, true);
    }
    
    public Token requireToken (Tokenizer toker, Token t) throws Exception {
	return requireToken(toker, t, true);
    }

    public Token requireToken (Tokenizer toker, Token t, boolean ignoreSpace) 
	throws Exception 
    {
	if (ignoreSpace) skipWhite(toker);

	Token next = toker.getToken();
	if (next == null) {
	    throw new Exception("Unexpected end of file found");
	}
	if (! next.equals(t)) {
	    System.err.println("Expecting: " + t.toString());
	    System.err.println("Got: " + next.toString());
	    throw new Exception("Unexpected token found at " + toker.locationString());
	}
	tokenlist.add(next);

	if (ignoreSpace) skipWhite(toker);

	return next;
    }

    public TokenStringLiteral 
	getStringLiteral (Tokenizer toker)
	throws Exception 
    {
	return getStringLiteral(toker, true);
    }

    public TokenStringLiteral
	getStringLiteral (Tokenizer toker, boolean ignoreSpace)
	throws Exception 
    {
	if (ignoreSpace) skipWhite(toker);

	if (! (toker.peek() instanceof TokenStringLiteral)) {
	    throw new Exception("Expected string literal");
	}
	tokenlist.add(toker.peek());
	return (TokenStringLiteral) toker.getToken();
    }

    public TokenIdent getIdent (Tokenizer toker) throws Exception {
	return getIdent(toker, true, true);
    }

    public TokenIdent getIdent (Tokenizer toker, boolean addToList) throws Exception  {
	return getIdent(toker, addToList, true);
    }


    public TokenIdent getIdent (Tokenizer toker, 
				boolean addToList,
				boolean ignoreSpace) throws Exception 
    {
	Token id = toker.peek();
	if (! (id instanceof TokenIdent)) {
	    throw new Exception("Expected identifer at " + toker.locationString());
	}
	if (addToList) {
	    eatToken(toker, ignoreSpace);
	}
	return (TokenIdent) id;
    }

    
    public void skipWhite (Tokenizer toker) throws Exception {
	Token next;
	while ((next=toker.peek()) != null) {
	    if (next.isNecessary()) {
		return;
	    }
	    tokenlist.add(toker.getToken());
	}
    }

    public FilePos getFilePos () 
    {
	// most nodes should set their position
	if (startPos != null)
	    return startPos;

	// if the node didn't record its position, try to figure it out
	// from where the first token is at
    	ListIterator li = tokenlist.listIterator(0);
	if (li.hasNext()) {
	    Object el = li.next();

	    // usually tokenlist is tokens, but can also be nodes:
	    if (el instanceof Node) {
		Node eln = (Node) el;
		return eln.getFilePos();
	    }

	    Token elt = (Token) el;
	    return elt.getFilePos();

	}
	return null;
    }

    protected static void dbg (String s) {
	System.err.println(s);
    }

    public Type getType (Checker ck) throws Exception
    {
	throw new Exception("FIXME: getType(ck) not implemented in "+this);
    }    

    public Type getType (Checker ck, Type wanted) throws Exception
    {
	return getType(ck);
    }    

    // kinda a crappy part to put this, perhaps.  but all expr
    // nodes don't inherit from NodeExpr.  maybe they should?
    public boolean isLValue () 
    {
	// hack:  only NodeTerms inside NodeExprs can be true
	if (this instanceof NodeExpr) {
	    NodeExpr ne = (NodeExpr) this;
	    Node n = ne.getExpr();
	    if (n instanceof NodeTerm) {
		NodeTerm nt = (NodeTerm) n;
		return nt.isLValue();
	    }
	}
	return false;
    }

    public boolean makeAsString(Checker ck)
    {
	System.err.println("Node::makeAsString() on "+this);
	return false;
    }
};
