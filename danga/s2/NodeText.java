package danga.s2;

public class NodeText extends Node
{
    String text;

    public String getText () {
	return text;
    }

    public static boolean canStart (Tokenizer toker) throws Exception
    {
	Token t = toker.peek();
	
	if (t instanceof TokenIdent ||
	    t instanceof TokenIntegerLiteral ||
	    t instanceof TokenStringLiteral) 
	    return true;

	return false;	    
    }
    
    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeText nt = new NodeText();
	
	nt.skipWhite(toker);
	Token t = toker.peek();
	
	if (t instanceof TokenIdent ||
	    t instanceof TokenIntegerLiteral ||
	    t instanceof TokenStringLiteral) {
	    
	    if (t instanceof TokenIdent) {
		TokenIdent ti = (TokenIdent) t;
		nt.text = ti.getIdent();
		ti.setType(TokenIdent.STRING);
	    }
	    if (t instanceof TokenIntegerLiteral) {
		int iv = ((TokenIntegerLiteral)t).val;
		nt.text = (new Integer(iv)).toString();
	    }
	    if (t instanceof TokenStringLiteral) {
		TokenStringLiteral ts = (TokenStringLiteral) t;
		//FIXME: check for unclosed side.
		nt.text = ts.text;
	    }
    
	    nt.eatToken(toker);
	} else {
	    throw new Exception("Expecting text (integer, string, or identifer)");
	}
	
	return nt;
    }

    public void asS2 (Indenter o)
    {
	o.write(Backend.quoteString(text));
    }

};
