package danga.s2;

public class NodeLogAndExpr extends Node
{
    Node lhs;
    Node rhs;
    
    public static boolean canStart (Tokenizer toker) throws Exception
    {
	return NodeEqExpr.canStart(toker);
    }
    
    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeLogAndExpr n = new NodeLogAndExpr();

	n.lhs = NodeEqExpr.parse(toker);
	n.addNode(n.lhs);

	Token t = toker.peek();
	if (t.equals(TokenKeyword.AND)) {
	    n.eatToken(toker);
	} else {
	    return n.lhs;
	}

	n.rhs = NodeEqExpr.parse(toker);
	n.addNode(n.rhs);
	
	return n;
    }

    public Type getType (Checker ck) throws Exception
    {
	Type lt = lhs.getType(ck);
	Type rt = rhs.getType(ck);
	if (! lt.equals(rt) || ! lt.isBoolable()) 
	    throw new Exception("The left and right side of the 'and' expression must "+
				"both be of either type bool or int at "+getFilePos());
	return lt;
    }


    public void asS2 (Indenter o) {
	lhs.asS2(o);
	if (rhs != null) {
	    o.write(" and ");
	    rhs.asS2(o);
	}
    }

    public void asPerl (BackendPerl bp, Indenter o) {
	lhs.asPerl(bp, o);
	if (rhs != null) {
	    o.write(" && ");
	    rhs.asPerl(bp, o);
	}
    }

}
