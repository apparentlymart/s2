package danga.s2;

public class NodeVarDecl extends Node
{
    NodeNamedType nt;

    public static boolean canStart (Tokenizer toker) throws Exception
    {
	if (toker.peek().equals(TokenKeyword.VAR))
	    return true;
	return false;
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeVarDecl n = new NodeVarDecl();

	n.setStart(n.requireToken(toker, TokenKeyword.VAR));
	n.addNode(n.nt = (NodeNamedType) NodeNamedType.parse(toker));

	return n;
    }

    public Type getType () {
	return nt.getType();
    }

    public String getName () {
	return nt.getName();
    }

    public void populateScope (NodeStmtBlock nb) throws Exception
    {
	String name = nt.getName();
	Type et = nb.getLocalVar(name);
	if (et == null) {
	    nb.addLocalVar(name, nt.getType());
	    return;
	}
	throw new Exception("Can't mask local variable '"+name+"' at "+getFilePos());
    }

    public void asS2 (Indenter o) {
	// Note: no tabbing, as this may be in a foreach.  nodes using
	// VarDecl nodes must do their own tabbing (NodeClass, NodeVarDeclStmt)
	o.write("var ");
	nt.asS2(o);
    }

    public void asPerl (BackendPerl bp, Indenter o) {
	// Note: no tabbing, as this may be in a foreach.  nodes using
	// VarDecl nodes must do their own tabbing (NodeClass, NodeVarDeclStmt)
	o.write("my $" + nt.getName());
    }
}
