package danga.s2;

public class NodeDeleteStmt extends Node
{
    NodeVarRef var;

    public static boolean canStart (Tokenizer toker) throws Exception
    {	
	if (toker.peek().equals(TokenKeyword.DELETE))
	    return true;
	return false;
    }
    
    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeDeleteStmt n = new NodeDeleteStmt();
	Token t = toker.peek();

	n.requireToken(toker, TokenKeyword.DELETE);
	n.addNode(n.var = (NodeVarRef) NodeVarRef.parse(toker));
	n.requireToken(toker, TokenPunct.SCOLON);
	
	return n;
    }

    public void check (Layer l, Checker ck) throws Exception
    {
	// type check the innards, but we don't care what type it
	// actually is.
	var.getType(ck);
	
	// but it must be a hash reference
	if (! var.isHashElement()) {
	    throw new Exception("Delete statement argument is not a hash at "+
				var.getFilePos());
	}
    }

    public void asS2 (Indenter o)
    {
	o.tabwrite("delete ");
	var.asS2(o);
	o.writeln(";");
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {
	o.tabwrite("delete ");
	var.asPerl(bp, o);
	o.writeln(";");
    }
};
