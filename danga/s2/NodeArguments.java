package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;

public class NodeArguments extends Node
{
    public LinkedList args = new LinkedList();

    public static NodeArguments makeEmptyArgs () 
    {
	NodeArguments n = new NodeArguments();
	n.args = new LinkedList();
	return n;
    }

    public void addArg (NodeExpr ne) {
	args.add(ne);
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeArguments n = new NodeArguments();
	
	n.setStart(n.requireToken(toker, TokenPunct.LPAREN));
	boolean loop = true;
	while (loop) {
	    Token tp = toker.peek();
	    if (tp.equals(TokenPunct.RPAREN)) {
		n.eatToken(toker);
		loop = false;
	    } else {
		Node expr = NodeExpr.parse(toker);
		n.args.add(expr);
		n.addNode(expr);
		
		if (toker.peek().equals(TokenPunct.COMMA)) {
		    n.eatToken(toker);
		}
	    }
	}

	return n;
    }

    public void asS2 (Indenter o) 
    {
	o.write("(");

	ListIterator li = args.listIterator(0);
	boolean didFirst = false;
	while (li.hasNext()) {
	    Node n = (Node) li.next();
	    if (didFirst) {
		o.write(", ");
	    } else {
		didFirst = true;
	    }
	    n.asS2(o);
	}
	o.write(")");	    
    }

    public void asPerl (BackendPerl bp, Indenter o) {
	asPerl(bp, o, true);
    }

    public void asPerl (BackendPerl bp, Indenter o, boolean doCurlies) 
    {
	if (doCurlies)
	    o.write("(");

	ListIterator li = args.listIterator(0);
	boolean didFirst = false;
	while (li.hasNext()) {
	    Node n = (Node) li.next();
	    if (didFirst) {
		o.write(", ");
	    } else {
		didFirst = true;
	    }
	    n.asPerl(bp, o);
	}

	if (doCurlies)
	    o.write(")");	    
    }

    public String typeList (Checker ck) throws Exception
    {
	StringBuffer sb = new StringBuffer(50);
	if (args.size() == 0) return sb.toString();

	ListIterator li = args.listIterator();
	boolean first = true;
	while (li.hasNext()) {
	    NodeExpr n = (NodeExpr) li.next();
	    if (! first) sb.append(",");
	    first = false;
	    sb.append(n.getType(ck).toString());
	}

	return sb.toString();
    }

};
