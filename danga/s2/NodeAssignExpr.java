package danga.s2;

public class NodeAssignExpr extends Node
{
    Node lhs;
    TokenPunct op;
    Node rhs;

    boolean rhsCtor;  // right hand side is a constructor
    String ctorId;
    boolean builtin;
    String baseType;    
    
    public static boolean canStart (Tokenizer toker) throws Exception
    {
	return NodeCondExpr.canStart(toker);
    }
    
    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeAssignExpr n = new NodeAssignExpr();

	n.lhs = NodeCondExpr.parse(toker);
	n.addNode(n.lhs);

	if (toker.peek().equals(TokenPunct.ASSIGN)) {
	    n.op = (TokenPunct) toker.peek();
	    n.eatToken(toker);
	    n.skipWhite(toker);
	} else {
	    return n.lhs;
	}

	n.rhs = NodeAssignExpr.parse(toker);
	n.addNode(n.rhs);

	return n;
    }

    public Type getType (Checker ck, Type wanted) throws Exception 
    {
	Type lt = lhs.getType(ck);
        Type want = Type.STRING.equals(lt) ? Type.STRING : null;
	Type rt = rhs.getType(ck, want);

	if (! (lhs instanceof NodeTerm) ||
	    ! lhs.isLValue()) {
	    throw new Exception("Left-hand side of assignment at "+getFilePos()+
				" must be an lvalue.");
	}
	if (! ck.typeIsa(rt, lt)) {
	    // types don't match, but maybe class for left hand side has
	    // a constructor which takes a string.
	    if (lt.isSimple() && rt.equals(Type.STRING)) {
		baseType = lt.baseType();
		ctorId = baseType+"::"+baseType+"(string)";
		Type et = ck.functionType(ctorId);
		builtin = ck.isFuncBuiltin(ctorId);
		if (et != null && et.equals(lt)) {
		    // there's a good constructor, so change right hand side
		    // later to call that constructor instead
		    rhsCtor = true;
		    return lt;
		}
	    }
	    throw new Exception("Can't assign type "+rt+" to "+lt+" at "+
				getFilePos());
	}

	return lt;
    }

    public void asS2 (Indenter o) 
    {
	lhs.asS2(o);
	if (op != null) {
	    o.write(" = ");
	    rhs.asS2(o);
	}
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {
	lhs.asPerl(bp, o);
	if (op != null) {
	    o.write(" = ");
	    if (! rhsCtor) {
		rhs.asPerl(bp, o);
	    } else {
		if (builtin) {
		    o.write("S2::Builtin::"+baseType+"__"+baseType+
			    "($_ctx, ");
		} else {
		    o.write("$_ctx->[VTABLE]->{get_func_num("+
			    bp.quoteString(ctorId) + ")}->($_ctx, ");
		}
		rhs.asPerl(bp, o);
		o.write(")");
	    }
	}
    }

}

