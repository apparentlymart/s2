package danga.s2;

public class NodeProduct extends Node
{
    Node lhs;
    TokenPunct op;
    Node rhs;

    public static boolean canStart (Tokenizer toker) throws Exception
    {
	return NodeUnaryExpr.canStart(toker);
    }
    
    public static Node parse (Tokenizer toker) throws Exception
    {
	Node lhs = NodeUnaryExpr.parse(toker);

	while (toker.peek().equals(TokenPunct.MULT) ||
	       toker.peek().equals(TokenPunct.DIV) ||
               toker.peek().equals(TokenPunct.MOD)) {
	    lhs = parseAnother(toker, lhs);
	}
	return lhs;
    }

    private static Node parseAnother (Tokenizer toker, Node lhs) throws Exception
    {
	NodeProduct n = new NodeProduct();	

	n.lhs = lhs;
	n.addNode(n.lhs);
	
	n.op = (TokenPunct) toker.peek();
	n.eatToken(toker);
	n.skipWhite(toker);

	n.rhs = NodeUnaryExpr.parse(toker);
	n.addNode(n.rhs);
	n.skipWhite(toker);

	return n;
    }

    public Type getType (Checker ck) throws Exception
    {
	Type lt = lhs.getType(ck);
	Type rt = rhs.getType(ck);
	if (! rt.equals(Type.INT)) {
	    throw new Exception("Right hand side of " + op.getPunct() + " operator is not an integer at "+
				rhs.getFilePos());
	}
	if (! lt.equals(Type.INT)) {
	    throw new Exception("Left hand side of " + op.getPunct() + " operator is not an integer at "+
				lhs.getFilePos());
	}
	
	return Type.INT;
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
        if (op == TokenPunct.DIV)
            o.write("int(");
	lhs.asPerl(bp, o);
	if (op != null) {
            if (op == TokenPunct.MULT)
                o.write(" * ");
            else if (op == TokenPunct.DIV)
                o.write(" / ");
            else if (op == TokenPunct.MOD)
                o.write(" % ");
	    rhs.asPerl(bp, o);
            if (op == TokenPunct.DIV)
                o.write(")");
	}
    }

}
