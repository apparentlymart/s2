package danga.s2;

public class NodePrintStmt extends Node
{
    NodeExpr expr;
    boolean doNewline = false;

    public static boolean canStart (Tokenizer toker) throws Exception
    {	
	if (toker.peek().equals(TokenKeyword.PRINT) ||
	    toker.peek().equals(TokenKeyword.PRINTLN) ||
	    toker.peek() instanceof TokenStringLiteral)
	    return true;
	return false;
    }
    
    public static Node parse (Tokenizer toker) throws Exception
    {
	NodePrintStmt n = new NodePrintStmt();
	Token t = toker.peek();

	if (t.equals(TokenKeyword.PRINT)) {
	    n.setStart(n.eatToken(toker));
	}
	if (t.equals(TokenKeyword.PRINTLN)) {
	    n.setStart(n.eatToken(toker));
	    n.doNewline = true;
	}

	n.addNode(n.expr = (NodeExpr) NodeExpr.parse(toker));
	n.requireToken(toker, TokenPunct.SCOLON);

	return n;
    }

    public void check (Layer l, Checker ck) throws Exception
    {
        Type t = expr.getType(ck);
        if (t.equals(Type.INT) || t.equals(Type.STRING)) {
	    return;
	}
	throw new Exception("Print statement must print an expression of type "
			    +"int or string, not "+t+" at "+expr.getFilePos());
    }

    public void asS2 (Indenter o)
    {
	if (doNewline) 
	    o.tabwrite("println ");
	else 
	    o.tabwrite("print ");
	expr.asS2(o);
	o.writeln(";");
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {
	o.tabwrite("pout(");
	expr.asPerl(bp, o);
	if (doNewline) {
	    o.write(" . \"\\n\"");
	}
	o.writeln(");");
    }

};
