package danga.s2;

public class NodeRange extends Node
{
    Node lhs;
    Node rhs;

    public NodeRange() {
    }
    public NodeRange(Node start, Node end) {
	this.lhs = start;
	this.rhs = end;
    }

    public static boolean canStart (Tokenizer toker) throws Exception
    {
	return NodeLogOrExpr.canStart(toker);
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeRange n = new NodeRange();

	n.lhs = NodeLogOrExpr.parse(toker);
	n.addNode(n.lhs);

	if (toker.peek().equals(TokenPunct.DOTDOT)) {
	    n.eatToken(toker);
	    n.skipWhite(toker);
	} else {
	    return n.lhs;
	}

	n.rhs = NodeLogOrExpr.parse(toker);
	n.addNode(n.rhs);

	return n;
    }

    public Type getType (Checker ck) throws Exception
    {
        return getType(ck, null);
    }

    public Type getType (Checker ck, Type wanted) throws Exception
    {
	Type lt = lhs.getType(ck, wanted);
	Type rt = rhs.getType(ck, wanted);

        if (! lt.equals(Type.INT)) {
	    throw new Exception("Left operand of '..' range operator is not int at "+lhs.getFilePos());
	}
        if (! rt.equals(Type.INT)) {
	    throw new Exception("Right operand of '..' range operator is not int at "+rhs.getFilePos());
	}
        Type ret = new Type("int");
        ret.makeArrayOf();
        return ret;
    }

    public void asS2 (Indenter o)
    {
	lhs.asS2(o);
        o.write(" .. ");
        rhs.asS2(o);
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {
        o.write("[");
	lhs.asPerl(bp, o);
        o.write(" .. ");
        rhs.asPerl(bp, o);
        o.write("]");
    }

}
