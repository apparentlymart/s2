package danga.s2;

public class NodeRelExpr extends Node
{
    Node lhs;
    TokenPunct op;
    Node rhs;

    private Type myType;  // for backend later
    
    public static boolean canStart (Tokenizer toker) throws Exception
    {
	return NodeSum.canStart(toker);
    }
    
    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeRelExpr n = new NodeRelExpr();

	n.lhs = NodeSum.parse(toker);
	n.addNode(n.lhs);

	Token t = toker.peek();

	if (t.equals(TokenPunct.LT) || t.equals(TokenPunct.LTE) ||
	    t.equals(TokenPunct.GT) || t.equals(TokenPunct.GTE)) {
	    n.op = (TokenPunct) t;
	    n.eatToken(toker);
	    n.skipWhite(toker);
	} else {
	    return n.lhs;
	}

	n.rhs = NodeSum.parse(toker);
	n.skipWhite(toker);   

	return n;
    }

    public Type getType (Checker ck) throws Exception
    {
	Type lt = lhs.getType(ck);
	Type rt = rhs.getType(ck);
	if (! lt.equals(rt)) 
	    throw new Exception("The types of the left and right hand side of "+
				"comparision test expression don't match at "+getFilePos());
	if (lt.equals(Type.STRING) || lt.equals(Type.INT)) {
	    myType = lt;
	    return Type.BOOL;
	}
	throw new Exception ("Only bool, string, and int types can be compared at "+
			     getFilePos());
    }
    
    public void asS2 (Indenter o) 
    {
	lhs.asS2(o);
	if (op != null) {
	    o.write(" " + op.getPunct() + " ");
	    rhs.asS2(o);
	}
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {
	lhs.asPerl(bp, o);
	if (op != null) {
	    if (op.equals(TokenPunct.LT)) {
		if (myType.equals(Type.STRING))
		    o.write(" lt ");
		else 
		    o.write(" < ");
	    } else if (op.equals(TokenPunct.LTE)) {
		if (myType.equals(Type.STRING))
		    o.write(" le ");
		else 
		    o.write(" <= ");
	    } else if (op.equals(TokenPunct.GT)) {
		if (myType.equals(Type.STRING))
		    o.write(" gt ");
		else 
		    o.write(" > ");
	    } else if (op.equals(TokenPunct.GTE)) {
		if (myType.equals(Type.STRING))
		    o.write(" ge ");
		else 
		    o.write(" >= ");
	    }
	    rhs.asPerl(bp, o);
	}
    }

}
