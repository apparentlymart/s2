package danga.s2;

class TokenComment extends Token {

    String com;

    public boolean isNecessary() { return false; }

    public TokenComment (String com) {
	this.com = com;
    }

    public String getComment() {
	return com;
    }

    public String toString() {
	return ("[TokenComment]");
    }

    public static Token scan (Tokenizer t)
    {
	StringBuffer tbuf = new StringBuffer(80);

	while ((t.peekChar() != '\n')) {
	    tbuf.append(t.getChar());
	}
	return new TokenComment(tbuf.toString());
    }

    public void asHTML (Output o)
    {
	o.write("<span class=\"c\">" + com + "</span>");
    }
}
