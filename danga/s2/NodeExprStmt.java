package danga.s2;

public class NodeExprStmt extends Node
{
    NodeExpr expr;

    public static boolean canStart (Tokenizer toker) throws Exception
    {	
	return NodeExpr.canStart(toker);
    }
    
    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeExprStmt n = new NodeExprStmt();

	n.addNode(n.expr = (NodeExpr) NodeExpr.parse(toker));
	n.requireToken(toker, TokenPunct.SCOLON);

	return n;
    }

    public void check (Layer l, Checker ck) throws Exception
    {
	Type t = expr.getType(ck);  // checks the type
    }

    public void asS2 (Indenter o)
    {
	o.doTab();
	expr.asS2(o);
	o.writeln(";");
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {
	o.doTab();
	expr.asPerl(bp, o);
	o.writeln(";");
    }
 

};
