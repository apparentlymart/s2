package danga.s2;

public class NodeExpr extends Node
{
    Node expr;

    public NodeExpr () { }

    public NodeExpr (Node n) {
	expr = n;
    }

    public static boolean canStart (Tokenizer toker) throws Exception
    {
	return NodeAssignExpr.canStart(toker);
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeExpr n = new NodeExpr();
	n.expr = NodeAssignExpr.parse(toker);
	n.addNode(n.expr);
	return n;     // Note: always return a NodeExpr here
    }

    public void asS2 (Indenter o) 
    {
	expr.asS2(o);
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {
	expr.asPerl(bp, o);
    }

    public Type getType (Checker ck) throws Exception
    {
	return expr.getType(ck);
    }

    public Node getExpr () {
	return expr;
    }
}
