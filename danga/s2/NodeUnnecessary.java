package danga.s2;

public class NodeUnnecessary extends Node
{
    public static Node parse (Tokenizer toker) throws Exception
    {
	Node n = new NodeUnnecessary();
	n.skipWhite(toker);
	return n;
    }

    public static boolean canStart (Tokenizer toker) throws Exception
    {
	if (toker.peek().isNecessary() == false)
	    return true;
	return false;
    }

    public void asS2 (Indenter o) {
	// do nothing when making the canonical S2
    }

    public void asPerl (BackendPerl bp, Indenter o) {
	// do nothing when doing the perl output
    }

    public void check (Layer l, Checker ck) throws Exception {
	// nothing can be wrong with whitespace and comments
    } 

};
