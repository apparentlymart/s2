package danga.s2;

class TokenIntegerLiteral extends Token {

    int val;

    public TokenIntegerLiteral (int val) {
	this.val = val;
    }

    public int getInteger() {
	return val;
    }

    public void asS2 (Indenter o) {
	o.write((new Integer(val)).toString());
    }

    public void asPerl (BackendPerl bp, Indenter o) {
	asS2(o);  // same as S2 (just an integer)
    }

    public String toString() {
	StringBuffer ret = new StringBuffer("[TokenIntegerLiteral] = ");
	ret.append((new Integer(val)).toString());
	return ret.toString();
    }

    public static Token scan (Tokenizer t)
    {
	StringBuffer tbuf = new StringBuffer(15);

	while (t.peekChar() >= '0' && t.peekChar() <= '9') {
	    tbuf.append(t.getChar());
	}

	return new TokenIntegerLiteral((new Integer(tbuf.toString())).intValue());
    }

    public void asHTML (Output o)
    {
	o.write("<span class=\"n\">" +
		val + "</span>");
    }

}
