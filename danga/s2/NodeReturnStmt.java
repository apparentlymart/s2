package danga.s2;

public class NodeReturnStmt extends Node
{
    NodeExpr expr;

    public static boolean canStart (Tokenizer toker) throws Exception
    {	
	if (toker.peek().equals(TokenKeyword.RETURN))
	    return true;
	return false;
    }
    
    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeReturnStmt n = new NodeReturnStmt();

	n.setStart(n.requireToken(toker, TokenKeyword.RETURN));

	// optional return expression
	if (NodeExpr.canStart(toker)) {
	    n.addNode(n.expr = (NodeExpr) NodeExpr.parse(toker));
	}

	n.requireToken(toker, TokenPunct.SCOLON);

	return n;
    }

    public void check (Layer l, Checker ck) throws Exception
    {
	Type exptype = ck.getReturnType();
	Type rettype = expr != null ? expr.getType(ck) : Type.VOID;

	if (! ck.typeIsa(rettype, exptype)) {
	    throw new Exception("Return type of "+rettype+" at "+
				getFilePos()+" doesn't match expected type of "+
				exptype+" for this function.");
	}
    }

    public void asS2 (Indenter o)
    {
	o.tabwrite("return");
	if (expr != null) {
	    o.write(" ");
	    expr.asS2(o);
	}
	o.writeln(";");
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {
	o.tabwrite("return");
	if (expr != null) {
	    o.write(" ");
	    expr.asPerl(bp, o);
	}
	o.writeln(";");
    }


};
