package danga.s2;

public class NodeAssignExpr extends Node
{
    Node lhs;
    TokenPunct op;
    Node rhs;

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
	Type lt = lhs.getType(ck, wanted);
	Type rt = rhs.getType(ck, lt);

        if (lt.isReadOnly()) {
	    throw new Exception("Left-hand side of assignment at "+getFilePos()+
				" is a read-only value.");
        }

	if (! (lhs instanceof NodeTerm) ||
	    ! lhs.isLValue()) {
	    throw new Exception("Left-hand side of assignment at "+getFilePos()+
				" must be an lvalue.");
	}

	if (ck.typeIsa(rt, lt))
            return lt;

        // types don't match, but maybe class for left hand side has
        // a constructor which takes a string.
        if (rt.equals(Type.STRING) && ck.isStringCtor(lt)) {
            rt = rhs.getType(ck, lt);
            if (lt.equals(rt)) return lt;
        }
        
        throw new Exception("Can't assign type "+rt+" to "+lt+" at "+
                            getFilePos());
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
            rhs.asPerl(bp, o);
	}
    }

}

