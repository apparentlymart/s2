package danga.s2;

class TokenStringLiteral extends Token {

    int quotesLeft;
    int quotesRight;
    String text;

    public int getQuotesLeft () { return quotesLeft; }
    public int getQuotesRight () { return quotesRight; }
    public void setQuotesLeft (int c) { quotesLeft = c; }
    public void setQuotesRight (int c) { quotesRight = c; }

    public Object clone () {
	return new TokenStringLiteral(text, quotesLeft, quotesRight);
    }

    public TokenStringLiteral (String text) {
	this(text, 1, 1);

    }
    public TokenStringLiteral (String text, int quotesLeft, int quotesRight) {
	this.text = text;
	this.quotesLeft = quotesLeft;
	this.quotesRight = quotesRight;
    }

    public String getString() {
	return text;
    }

    public String toString() {
	StringBuffer ret = new StringBuffer("[TokenStringLiteral] = ");
	if (quotesLeft == 0) { ret.append("("); }
	else if (quotesLeft == 1) { ret.append("<"); }
	else if (quotesLeft == 3) { ret.append("<<"); }
	ret.append(text);
	if (quotesRight == 0) { ret.append(")"); }
	else if (quotesRight == 1) { ret.append(">"); }
	else if (quotesRight == 3) { ret.append(">>"); }

	return ret.toString();
    }

    public void asHTML (Output o) 
    {
	StringBuffer ret = new StringBuffer();
	ret.append(makeQuotes(quotesLeft));
	ret.append(Backend.quoteStringInner(text));
	ret.append(makeQuotes(quotesRight));

	o.write("<font color=" + BackendHTML.StringColor + ">" + 
		BackendHTML.quoteHTML(ret.toString()) + "</font>");
    }

    public static Token scan (Tokenizer t) throws Exception
    {
	boolean inTriple = false;
	boolean continued = false;
	
	if (t.inString == 0)  {
	    // see if this is a triple quoted string,
	    // like python.  if so, don't need to escape quotes
	    t.getRealChar();               // 1
	    if (t.peekChar() == '"') {
		t.getChar();               // 2
		if (t.peekChar() == '"') {
		    t.getRealChar();       // 3
		    inTriple = true;
		} else {
		    t.inString = 0;
		    return new TokenStringLiteral("", 1, 1);
		}
	    }
	} else if (t.inString == 3) {
	    continued = true;
	    inTriple = true;
	} else if (t.inString == 1) {
	    continued = true;	    
	}
    
	StringBuffer tbuf = new StringBuffer(inTriple ? 500 : 80);
    
	while (true) {
	    if (t.peekChar() == '"') {
		if (! inTriple) {
		    t.getChar();
		    t.inString = 0;
		    return new TokenStringLiteral(tbuf.toString(), continued ? 0 : 1, 1);
		} else {
		    t.getChar();                    // 1
		    if (t.peekChar() == '"') {
			t.getChar();                // 2
			if (t.peekChar() == '"') {
			    t.getChar();            // 3
			    t.inString = 0;
			    return new TokenStringLiteral(tbuf.toString(), continued ? 0 : 3, 3);
			} else {
			    tbuf.append('"');
			    tbuf.append('"');
			}
		    } else {
			tbuf.append('"');
		    }
		}
	    } else {
		if (t.peekChar() == '$') {
		    t.inString = inTriple ? 3 : 1;
		    return new TokenStringLiteral(tbuf.toString(), 
						  continued ? 0 : (inTriple ? 3 : 1), 
						  0);
		}

		if (t.peekChar() == '\\') {
		    t.getRealChar();    // skip the backslash.  next thing will be literal.

		    if (t.peekChar() == 'n') {
			t.forceNextChar('\n');
		    }
		}
		
		tbuf.append(t.getRealChar());
	    }
	}
    }

    public void asS2 (Indenter o)
    {
	o.write(makeQuotes(quotesLeft));
	o.write(Backend.quoteStringInner(text));
	o.write(makeQuotes(quotesRight));
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {
	o.write(bp.quoteString(text));
    }

    private String makeQuotes(int i) {
	if (i == 0) return "";
	if (i == 1) return "\"";
	if (i == 3) return "\"\"\"";
	return "XXX";
    }
}
