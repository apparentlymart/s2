package danga.s2;

public class NodeType extends Node
{
    private Type type;

    public Type getType () { return type; }

    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeType n = new NodeType();

	TokenIdent base = (TokenIdent) n.getIdent(toker, true, false);
	base.setType(TokenIdent.TYPE);

	n.type = new Type(base.getIdent());
	while (toker.peek().equals(TokenPunct.LBRACK) ||
	       toker.peek().equals(TokenPunct.LBRACE)) {

	    Token t = toker.peek();

	    n.eatToken(toker, false);
	    if (t.equals(TokenPunct.LBRACK)) {
		n.requireToken(toker, TokenPunct.RBRACK, false);
		n.type.makeArrayOf();
	    }
	    if (t.equals(TokenPunct.LBRACE)) {
		n.requireToken(toker, TokenPunct.RBRACE, false);
		n.type.makeHashOf();
	    }
	}

	// If the type was a simple type, we have to remove whitespace,
	// since we explictly said not to above.
	n.skipWhite(toker);

	return n;
    }

    public void asS2 (Indenter o) 
    {
	o.write(type.toString());
    }

};
