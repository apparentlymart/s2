package danga.s2;

import java.util.StringTokenizer;

class TokenWhitespace extends Token {

    String ws;

    public boolean isNecessary() { return false; }

    public TokenWhitespace (String ws) {
	this.ws = ws;
    }

    public String getWhitespace() {
	return ws;
    }

    public String toString() {
	return ("[TokenWhitespace]");
    }

    public static Token scan (Tokenizer t)
    {
	StringBuffer tbuf = new StringBuffer(200);
    
	while ((t.peekChar() == ' '  || t.peekChar() == '\t' ||
		t.peekChar() == '\n' || t.peekChar() == '\r')) {
	    tbuf.append(t.getChar());
	}

	return new TokenWhitespace(tbuf.toString());
    }
  
    public void asHTML (Output o) {
	StringTokenizer st = new StringTokenizer(ws, "\n", true);
	while (st.hasMoreTokens()) {
	    String s = st.nextToken();
	    if (s.equals("\n")) {
		if (BackendHTML.addBreaks) { o.write("<br>"); }
		o.newline();
	    } else {
		o.write(s);
	    }
	}
    }

}
