package danga.s2;

class TokenIdent extends Token {

    public final static int DEFAULT = 0;
    public final static int TYPE = 1;
    public final static int STRING = 2;

    int type;
    String ident;

    // dummy constructor for subclass
    public TokenIdent () {
	this.ident = null;
    }

    public TokenIdent (String ident) {
	this.ident = ident;
    }

    public String getIdent() {
	return ident;
    }

    public String toString() {
	return ("[TokenIdent] = " + ident);
    }

    public void setType (int type) {
	this.type = type;
    }

    public static boolean canStart (Tokenizer t)
    {
	char nextchar = t.peekChar();
	if ((nextchar >= 'a' && nextchar <= 'z') ||
	    (nextchar >= 'A' && nextchar <= 'Z') ||
	    (nextchar == '_'))
	    return true;
	return false;
    }

    public static Token scan (Tokenizer t)
    {
	StringBuffer tbuf = new StringBuffer(15);

	while ((t.peekChar() >= 'a' && t.peekChar() <= 'z') ||
	       (t.peekChar() >= 'A' && t.peekChar() <= 'Z') ||
	       (t.peekChar() >= '0' && t.peekChar() <= '9') ||
	       (t.peekChar() == '_'))
	    {

		tbuf.append(t.getChar());
	    }

	String token = tbuf.toString();
	Token kwtok = TokenKeyword.tokenFromString(token);
	Token ret = (kwtok != null) ? kwtok : new TokenIdent(token);

	return ret;
    }

    public void asHTML (Output o)
    {
	String c = BackendHTML.IdentColor;
	if (type == TYPE) c = BackendHTML.TypeColor;
	else if (type == STRING) c = BackendHTML.StringColor;

        // FIXME: TODO: Don't hardcode internal types, intelligently recognise
        //             places where types and class references occur and
        //             make them class="t"
        if (ident.equals("int") || ident.equals("void") ||
            ident.equals("string") || ident.equals("bool")) {

	    o.write("<span class=\"t\">" + ident + "</span>");
	} else {
	    o.write("<span class=\"i\">" + ident + "</span>");
        }
    }

}

