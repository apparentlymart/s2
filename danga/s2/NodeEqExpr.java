package danga.s2;

public class NodeEqExpr extends Node
{
    Node lhs;
    TokenPunct op;
    Node rhs;

    // use this for the backend to decide which add operator to use
    private Type myType;
    
    public static boolean canStart (Tokenizer toker) throws Exception
    {
	return NodeRelExpr.canStart(toker);
    }
    
    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeEqExpr n = new NodeEqExpr();

	n.lhs = NodeRelExpr.parse(toker);
	n.addNode(n.lhs);

	Token t = toker.peek();

	if (t.equals(TokenPunct.EQ) || t.equals(TokenPunct.NE)) {
	    n.op = (TokenPunct) t;
	    n.eatToken(toker);
	    n.skipWhite(toker);
	} else {
	    return n.lhs;
	}

	n.rhs = NodeRelExpr.parse(toker);
	n.skipWhite(toker);   

	return n;
    }

    public Type getType (Checker ck) throws Exception
    {
	Type lt = lhs.getType(ck);
	Type rt = rhs.getType(ck);
	if (! lt.equals(rt)) 
	    throw new Exception("The types of the left and right hand side of "+
				"equality test expression don't match at "+getFilePos());
	myType = lt;
	if (lt.equals(Type.BOOL) || lt.equals(Type.STRING) || lt.equals(Type.INT)) {
	    return Type.BOOL;
	}
	throw new Exception ("Only bool, string, and int types can be tested for "+
			     "equality at "+getFilePos());
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
	    if (op.equals(TokenPunct.EQ)) {
		if (myType.equals(Type.STRING))
		    o.write(" eq ");
		else 
		    o.write(" == ");
	    } else {
		if (myType.equals(Type.STRING))
		    o.write(" ne ");
		else 
		    o.write(" != ");
	    }
	    rhs.asPerl(bp, o);
	}
    }


}
