package danga.s2;

public class NodeForeachStmt extends Node
{
    NodeExpr listexpr;
    NodeStmtBlock stmts;
    NodeVarDecl vardecl;
    NodeVarRef varref;
    boolean isHash;   // otherwise it's an array or a string
    boolean isString;

    public static boolean canStart (Tokenizer toker) throws Exception
    {
	if (toker.peek().equals(TokenKeyword.FOREACH))
	    return true;
	return false;
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeForeachStmt n = new NodeForeachStmt();

	n.requireToken(toker, TokenKeyword.FOREACH);

	if (NodeVarDecl.canStart(toker)) {
	    n.addNode(n.vardecl = (NodeVarDecl) NodeVarDecl.parse(toker));
	} else {
	    n.addNode(n.varref = (NodeVarRef) NodeVarRef.parse(toker));
	}

	// expression in parenthesis representing an array to iterate over:
	n.requireToken(toker, TokenPunct.LPAREN);
	n.addNode(n.listexpr = (NodeExpr) NodeExpr.parse(toker));
	n.requireToken(toker, TokenPunct.RPAREN);

	// and what to do on each element
	n.addNode(n.stmts = (NodeStmtBlock) NodeStmtBlock.parse(toker));

	return n;
    }

    public void check (Layer l, Checker ck) throws Exception
    {
	Type ltype = listexpr.getType(ck);
	isHash = false;

	if (ltype.isHashOf()) {
	    isHash = true;
	} else if (ltype.equals(Type.STRING)) { // Iterate over characters in a string
            isString = true;
        } else if (! ltype.isArrayOf()) {
	    throw new Exception("Must use an array, hash or string in foreach statement at "+
				listexpr.getFilePos());
	}

	Type itype = null;
	if (vardecl != null) {
	    vardecl.populateScope(stmts);
	    itype = vardecl.getType();
	}
	if (varref != null) {
	    itype = varref.getType(ck);
	}

	if (isHash) {
	    // then iter type must be a string or int
	    if (! itype.equals(Type.STRING) && ! itype.equals(Type.INT)) {
		throw new Exception("Foreach iteration variable must be a "+
				    "string or int when interating over the keys "+
				    "in a hash at "+getFilePos());
	    }
	} else if (isString) {
            if (! itype.equals(Type.STRING)) {
                throw new Exception("Foreach iteration variable must be a "+
                                    "string when interating over the characters "+
                                    "in a string at "+getFilePos());
            }
        } else {
	    // iter type must be the same as the list type minus
	    // the final array ref

            // figure out the desired type
            Type dtype = (Type) ltype.clone();
            dtype.removeMod();

	    if (! dtype.equals(itype)) {
		throw new Exception("Foreach iteration variable is of type "+
				    itype+", not the expected type of "+dtype+" at "+
				    getFilePos());
	    }
	}

	ck.pushLocalBlock(stmts);
	stmts.check(l, ck);
	ck.popLocalBlock();
    }

    public void asS2 (Indenter o)
    {
	o.tabwrite("foreach ");
	if (vardecl != null)
	    vardecl.asS2(o);
	if (varref != null)
	    varref.asS2(o);
	o.write(" (");
	listexpr.asS2(o);
	o.write(") ");
	stmts.asS2(o);
	o.newline();
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {
	o.tabwrite("foreach ");
	if (vardecl != null)
	    vardecl.asPerl(bp, o);
	if (varref != null)
	    varref.asPerl(bp, o);
	if (isHash) {
	    o.write(" (keys %{");
	} else if (isString) {
            o.write(" (S2::get_characters(");
        } else {
	    o.write(" (@{");
	}
	listexpr.asPerl(bp, o);
        if (isString) {
            o.write(")) ");
        } else {
            o.write("}) ");
        }
	stmts.asPerl(bp, o);
	o.newline();
    }

};
