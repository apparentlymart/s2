package danga.s2;

public class NodeSum extends Node
{
    Node lhs;
    TokenPunct op;
    Node rhs;

    // use this for the backend to decide which add operator to use
    private Type myType;

    public NodeSum () {
    }

    public NodeSum (Node lhs, TokenPunct op, Node rhs)
    {
	this.lhs = lhs;
	this.op = op;
	this.rhs = rhs;
    }

    public static boolean canStart (Tokenizer toker) throws Exception
    {
	return NodeProduct.canStart(toker);
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	Node lhs = NodeProduct.parse(toker);
	lhs.skipWhite(toker);

	while(toker.peek().equals(TokenPunct.PLUS) ||
	      toker.peek().equals(TokenPunct.MINUS)) {
	    lhs = parseAnother(toker, lhs);
	}
	return lhs;
    }

    private static Node parseAnother (Tokenizer toker, Node lhs) throws Exception
    {
	NodeSum n = new NodeSum();	

	n.lhs = lhs;
	n.addNode(n.lhs);
	
	n.op = (TokenPunct) toker.peek();
	n.eatToken(toker);
	n.skipWhite(toker);

	n.rhs = NodeProduct.parse(toker);
	n.addNode(n.rhs);
	n.skipWhite(toker);

	return n;
    }

    public Type getType (Checker ck) throws Exception
    {
        return getType(ck, null);
    }

    public Type getType (Checker ck, Type wanted) throws Exception
    {
	Type lt = lhs.getType(ck, wanted);
	Type rt = rhs.getType(ck, wanted);
	if (! (lt.equals(Type.INT) || lt.equals(Type.STRING))) {
	    if (lhs.makeAsString(ck)) 
		lt = Type.STRING;
	    else 
	    throw new Exception("Left hand side of + operator is "+lt+", not a string or "+
				"integer at "+lhs.getFilePos());
	}
	if (! (rt.equals(Type.INT) || rt.equals(Type.STRING))) {
	    if (rhs.makeAsString(ck)) 
		rt = Type.STRING;
	    else 
	    throw new Exception("Right hand side of + operator is "+rt+", not a string or "+
				"integer at "+rhs.getFilePos());
	}
        // can't subtract strings
        if (op == TokenPunct.MINUS && (lt.equals(Type.STRING) ||
                                       rt.equals(Type.STRING))) {
            throw new Exception("Can't subtract strings at "+rhs.getFilePos());
        }

	// all summations involving a string on either side are promoted
	// to a concatenation
	if (lt.equals(Type.STRING) || rt.equals(Type.STRING)) {
	    return (myType = Type.STRING);
	}
	return (myType = Type.INT);
    }
    
    public void asS2 (Indenter o) 
    {
	BackendS2.LParen(o);
	lhs.asS2(o);
	if (op != null) {
	    o.write(" " + op.getPunct() + " ");
	    rhs.asS2(o);
	}
	BackendS2.RParen(o);
    }

    public void asPerl (BackendPerl bp, Indenter o) 
    {
	lhs.asPerl(bp, o);
	if (op != null) {
	    if (myType == Type.STRING)
		o.write(" . ");
	    else if (op == TokenPunct.PLUS)
		o.write(" + ");
	    else if (op == TokenPunct.MINUS)
		o.write(" - ");
	    rhs.asPerl(bp, o);
	}
    }

}
