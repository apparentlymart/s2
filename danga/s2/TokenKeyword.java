package danga.s2;

class TokenKeyword extends TokenIdent {

    public final static TokenKeyword CLASS     = new TokenKeyword("class");
    public final static TokenKeyword ELSE      = new TokenKeyword("else");
    public final static TokenKeyword ELSEIF    = new TokenKeyword("elseif");
    public final static TokenKeyword FUNCTION  = new TokenKeyword("function");
    public final static TokenKeyword IF        = new TokenKeyword("if");
    public final static TokenKeyword BUILTIN   = new TokenKeyword("builtin");
    public final static TokenKeyword PROPERTY  = new TokenKeyword("property");
    public final static TokenKeyword SET       = new TokenKeyword("set");
    public final static TokenKeyword STATIC    = new TokenKeyword("static");
    public final static TokenKeyword VAR       = new TokenKeyword("var");
    public final static TokenKeyword WHILE     = new TokenKeyword("while");
    public final static TokenKeyword FOREACH   = new TokenKeyword("foreach");
    public final static TokenKeyword PRINT     = new TokenKeyword("print");
    public final static TokenKeyword PRINTLN   = new TokenKeyword("println");
    public final static TokenKeyword NOT       = new TokenKeyword("not");
    public final static TokenKeyword AND       = new TokenKeyword("and");
    public final static TokenKeyword OR        = new TokenKeyword("or");
    public final static TokenKeyword XOR       = new TokenKeyword("xor");
    public final static TokenKeyword LAYERINFO = new TokenKeyword("layerinfo");
    public final static TokenKeyword EXTENDS   = new TokenKeyword("extends");
    public final static TokenKeyword RETURN    = new TokenKeyword("return");
    public final static TokenKeyword DELETE    = new TokenKeyword("delete");
    public final static TokenKeyword DEFINED   = new TokenKeyword("defined");
    public final static TokenKeyword NEW       = new TokenKeyword("new");
    public final static TokenKeyword TRUE      = new TokenKeyword("true");
    public final static TokenKeyword FALSE     = new TokenKeyword("false");
    public final static TokenKeyword REVERSE   = new TokenKeyword("reverse");
    public final static TokenKeyword SIZE      = new TokenKeyword("size");
    
    static TokenKeyword[] keywords = {
	CLASS, ELSE, ELSEIF, FUNCTION, IF, BUILTIN, PROPERTY, SET, 
	STATIC, VAR, WHILE, FOREACH, PRINT, PRINTLN, NEW, TRUE, FALSE,
	NOT, AND, OR, XOR, LAYERINFO, EXTENDS, RETURN, DELETE, DEFINED,
	REVERSE, SIZE
    };

    public TokenKeyword () {
	this.ident = null;
    }

    public TokenKeyword (String ident) {
	this.ident = ident;
    }

    public static TokenKeyword tokenFromString (String ident) {
	// FIXME: this is O(n).  do binary search or use hash
	for (int i=0; i<keywords.length; i++) {
	    if (keywords[i].ident.equals(ident))
		return keywords[i];
	}
	return null;
    }

    public String toString() {
	return ("[TokenKeyword] = " + ident);
    }

    public void asHTML (Output o) 
    {
	o.write("<b><font color=" + BackendHTML.KeywordColor + ">" + 
		ident + "</font></b>");
    }

}
