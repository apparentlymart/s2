package danga.s2;

public class NodeUnaryExpr extends Node
{
    boolean bNot = false;
    boolean bNegative = false;
    Node expr;
    
    public static boolean canStart (Tokenizer toker) throws Exception
    {
	return (toker.peek().equals(TokenPunct.MINUS) ||
		toker.peek().equals(TokenKeyword.NOT) ||
		NodeIncExpr.canStart(toker));
    }
    
    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeUnaryExpr n = new NodeUnaryExpr();

	if (toker.peek().equals(TokenPunct.MINUS)) {
	    n.bNegative = true;
	    n.eatToken(toker);
	    n.skipWhite(toker);
	} else if (toker.peek().equals(TokenKeyword.NOT)) {
	    n.bNot = true;
	    n.eatToken(toker);
	    n.skipWhite(toker);
	}

	Node expr = NodeIncExpr.parse(toker);

	if (n.bNegative || n.bNot) {
	    n.expr = expr;
	    n.addNode(n.expr);
	    return n;
	}
	return expr;
    }

    public Type getType (Checker ck) throws Exception
    {
        Type t = expr.getType(ck);
        if (bNegative) {
            if (! t.equals(Type.INT))
                throw new Exception("Can't use unary minus on non-integer.  Type = "+t);
            return Type.INT;
        }
        if (bNot) {
            if (! t.equals(Type.BOOL))
                throw new Exception("Can't use NOT operator on non-boolean.  Type = "+t);
            return Type.BOOL;
        }
        return null;
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {
	if (bNot) o.write("! ");
	if (bNegative) o.write("-");
	expr.asPerl(bp, o);
    }

    public void asS2 (Indenter o)
    {
	if (bNot) o.write("not ");
	if (bNegative) o.write("-");
	expr.asS2(o);
    }


}
