package danga.s2;

public class NodeIncExpr extends Node
{
    Node expr;
    TokenPunct op;
    boolean bPre = false;
    boolean bPost = false;
    
    public static boolean canStart (Tokenizer toker) throws Exception
    {
	return (toker.peek().equals(TokenPunct.INC) ||
		toker.peek().equals(TokenPunct.DEC) ||
		NodeTerm.canStart(toker));
    }
    
    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeIncExpr n = new NodeIncExpr();

	if (toker.peek().equals(TokenPunct.INC) ||
	    toker.peek().equals(TokenPunct.DEC)) {
	    n.bPre = true;
	    n.op = (TokenPunct) toker.peek();
	    n.setStart(n.eatToken(toker));
	    n.skipWhite(toker);
	}

	Node expr = NodeTerm.parse(toker);

	if (toker.peek().equals(TokenPunct.INC) ||
	    toker.peek().equals(TokenPunct.DEC)) {
	    if (n.bPre) throw new Exception("Unexpected -- or ++");
	    n.bPost = true;
	    n.op = (TokenPunct) toker.peek();
	    n.eatToken(toker);
	    n.skipWhite(toker);
	}
	
	if (n.bPre || n.bPost) {
	    n.expr = expr;
	    return n;
	}
	return expr;
    }

    public Type getType (Checker ck) throws Exception
    {
	if (! expr.isLValue()) {
	    throw new Exception("Post/pre-increment must operate on lvalue at "+
				expr.getFilePos());
	}
	return expr.getType(ck);
    }

    public void asS2 (Indenter o)
    {
	if (bPre) { o.write(op.getPunct()); }
	expr.asS2(o);
	if (bPost) { o.write(op.getPunct()); }
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {
	if (bPre) { o.write(op.getPunct()); }
	expr.asPerl(bp, o);
	if (bPost) { o.write(op.getPunct()); }
    }

}
