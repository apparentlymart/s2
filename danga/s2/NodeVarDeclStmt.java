package danga.s2;

public class NodeVarDeclStmt extends Node
{
    NodeVarDecl nvd;
    NodeExpr expr;

    public static boolean canStart (Tokenizer toker) throws Exception
    {
	return NodeVarDecl.canStart(toker);
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeVarDeclStmt n = new NodeVarDeclStmt();

	n.addNode(n.nvd = (NodeVarDecl) NodeVarDecl.parse(toker));

	if (toker.peek().equals(TokenPunct.ASSIGN)) {
	    n.eatToken(toker);
	    n.expr = (NodeExpr) NodeExpr.parse(toker);
	}
	n.requireToken(toker, TokenPunct.SCOLON);

	return n;
    }

    public void check (Layer l, Checker ck) throws Exception
    {
	nvd.populateScope(ck.getLocalScope());
	
	// check that the variable type is a known class
	Type t = nvd.getType();
	String bt = t.baseType();
	
	if (! Type.isPrimitive(bt) &&
	    ck.getClass(bt) == null) {
	    throw new Exception("Unknown type or class '"+bt+"' at "+
				nvd.getFilePos());
	}

	if (expr != null) {
	    Type et = expr.getType(ck);
	    if (! ck.typeIsa(et, t)) {
		throw new Exception("Can't initialize variable '"+nvd.getName()+"' "+
				    "of type "+t+" with expression of type "+
				    et+" at "+expr.getFilePos());
	    }
	}

	// can't be named $_ctx (conflicts with perl backend)
	String vname = nvd.getName();
	if (vname.equals("_ctx")) {
	    throw new Exception("Reserved variable name '_ctx' in use at "+
				getFilePos());
	}
    }

    public void asS2 (Indenter o) {
	o.doTab();
	nvd.asS2(o);
	if (expr != null) {
	    o.write(" = ");
	    expr.asS2(o);
	}
	o.writeln(";");
    }

    public void asPerl (BackendPerl bp, Indenter o) {
	o.doTab();
	nvd.asPerl(bp, o);

	if (expr != null) {
	    o.write(" = ");
	    expr.asPerl(bp, o);
	} else {
	    Type t = nvd.getType();
	    if (t.equals(Type.STRING)) {
		o.write(" = \"\"");
	    } else if (t.equals(Type.INT) || t.equals(Type.BOOL)) {
		o.write(" = 0");
	    }
	}
	//else {
	//    o.write(" = { '_type' => " + bp.quoteString(t.toString()) + "}");
	//}

	o.writeln(";");
    }
}
