package danga.s2;

public class NodeCondExpr extends Node
{
    Node test_expr;
    Node true_expr;
    Node false_expr;
    
    public static boolean canStart (Tokenizer toker) throws Exception
    {
	return NodeLogOrExpr.canStart(toker);
    }
    
    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeCondExpr n = new NodeCondExpr();

	n.test_expr = NodeLogOrExpr.parse(toker);
	n.addNode(n.test_expr);

	if (toker.peek().equals(TokenPunct.QMARK)) {
	    n.eatToken(toker);
	    n.skipWhite(toker);
	} else {
	    return n.test_expr;
	}

	n.true_expr = NodeLogOrExpr.parse(toker);
	n.addNode(n.true_expr);
	n.requireToken(toker, TokenPunct.COLON);

	n.false_expr = NodeLogOrExpr.parse(toker);
	n.addNode(n.false_expr);

	return n;
    }

    public Type getType (Checker ck) throws Exception
    {
	Type ctype = test_expr.getType(ck);
	if (! ctype.isBoolable()) {
	    throw new Exception("Conditional expression not a boolean at "+
				getFilePos());
	}
	Type lt = true_expr.getType(ck);
	Type rt = false_expr.getType(ck);
	if (! lt.equals(rt)) {
	    throw new Exception("Types must match in condition expression at "+
				getFilePos());
	}
	return lt;
    }

    public void asS2 (Indenter o) 
    {
	test_expr.asS2(o);
	if (true_expr != null) {
	    o.write(" ? ");
	    true_expr.asS2(o);
	    o.write(" : ");
	    false_expr.asS2(o);
	}
    }

    public void asPerl (BackendPerl bp, Indenter o) 
    {
	test_expr.asPerl(bp, o);
	if (true_expr != null) {
	    o.write(" ? ");
	    true_expr.asPerl(bp, o);
	    o.write(" : ");
	    false_expr.asPerl(bp, o);
	}
    }

    

}
