package danga.s2;

class TokenPunct extends Token {

    String punct;
    public TokenPunct (String punct) {
	this.punct = punct;
    }

    public String getPunct() {
	return punct;
    }

    public String toString() {
	return ("[TokenPunct] = " + punct);
    }

    public static final TokenPunct LTE    = new TokenPunct("<=");
    public static final TokenPunct LT     = new TokenPunct("<");
    public static final TokenPunct GTE    = new TokenPunct(">=");
    public static final TokenPunct GT     = new TokenPunct(">");
    public static final TokenPunct EQ     = new TokenPunct("==");
    public static final TokenPunct NE     = new TokenPunct("!=");
    public static final TokenPunct ASSIGN = new TokenPunct("=");
    public static final TokenPunct INC    = new TokenPunct("++");
    public static final TokenPunct PLUS   = new TokenPunct("+");
    public static final TokenPunct DEC    = new TokenPunct("--");
    public static final TokenPunct MINUS  = new TokenPunct("-");
    public static final TokenPunct DEREF  = new TokenPunct("->");
    public static final TokenPunct SCOLON = new TokenPunct(";");
    public static final TokenPunct COLON  = new TokenPunct(":");
    public static final TokenPunct DCOLON = new TokenPunct("::");
    public static final TokenPunct LOGAND = new TokenPunct("&&");
    public static final TokenPunct BITAND = new TokenPunct("&");
    public static final TokenPunct LOGOR  = new TokenPunct("||");
    public static final TokenPunct BITOR  = new TokenPunct("|");
    public static final TokenPunct MULT   = new TokenPunct("*");
    public static final TokenPunct DIV    = new TokenPunct("/");
    public static final TokenPunct MOD    = new TokenPunct("%");
    public static final TokenPunct NOT    = new TokenPunct("!");
    public static final TokenPunct DOT    = new TokenPunct(".");
    public static final TokenPunct DOTDOT = new TokenPunct("..");
    public static final TokenPunct LBRACE = new TokenPunct("{");
    public static final TokenPunct RBRACE = new TokenPunct("}");
    public static final TokenPunct LBRACK = new TokenPunct("[");
    public static final TokenPunct RBRACK = new TokenPunct("]");
    public static final TokenPunct LPAREN = new TokenPunct("(");
    public static final TokenPunct RPAREN = new TokenPunct(")");
    public static final TokenPunct COMMA  = new TokenPunct(",");
    public static final TokenPunct QMARK  = new TokenPunct("?");
    public static final TokenPunct DOLLAR = new TokenPunct("$");
    public static final TokenPunct HASSOC = new TokenPunct("=>");

    public static Token scan (Tokenizer t)
    {
	if (t.peekChar() == '$') {
	    t.getChar();
	    return TokenPunct.DOLLAR;
	}

	if (t.peekChar() == '<') {
	    t.getChar();
	    if (t.peekChar() == '=') {
		t.getChar();
		return TokenPunct.LTE;
	    } else {
		return TokenPunct.LT;
	    }
	}

	if (t.peekChar() == '>') {
	    t.getChar();
	    if (t.peekChar() == '=') {
		t.getChar();
		return TokenPunct.GTE;
	    } else {
		return TokenPunct.GT;
	    }
	}

	if (t.peekChar() == '=') {
	    t.getChar();
	    if (t.peekChar() == '=') {
		t.getChar();
		return TokenPunct.EQ;
            } else if (t.peekChar() == '>') {
                t.getChar();
                return TokenPunct.HASSOC;
	    } else {
		return TokenPunct.ASSIGN;
	    }
	}

	if (t.peekChar() == '+') {
	    t.getChar();
	    if (t.peekChar() == '+') {
		t.getChar();
		return TokenPunct.INC;
	    } else {
		return TokenPunct.PLUS;
	    }
	}

	if (t.peekChar() == '-') {
	    t.getChar();
	    if (t.peekChar() == '-') {
		t.getChar();
		return TokenPunct.DEC;
	    } else if (t.peekChar() == '>') {
		t.getChar();
		return TokenPunct.DEREF;
	    } else {
		return TokenPunct.MINUS;
	    }
	}

	if (t.peekChar() == ';') {
	    t.getChar();
	    return TokenPunct.SCOLON;
	}

	if (t.peekChar() == ':') {
	    t.getChar();
	    if (t.peekChar() == ':') {
		t.getChar();
		return TokenPunct.DCOLON;
	    } else {
		return TokenPunct.COLON;
	    }
	}

	if (t.peekChar() == '&') {
	    t.getChar();
	    if (t.peekChar() == '&') {
		t.getChar();
		return TokenPunct.LOGAND;
	    } else {
		return TokenPunct.BITAND;
	    }
	}

	if (t.peekChar() == '|') {
	    t.getChar();
	    if (t.peekChar() == '|') {
		t.getChar();
		return TokenPunct.LOGOR;
	    } else {
		return TokenPunct.BITOR;
	    }
	}

	if (t.peekChar() == '*') {
	    t.getChar();
	    return TokenPunct.MULT;
	}

	if (t.peekChar() == '/') {
	    t.getChar();
	    return TokenPunct.DIV;
	}
	if (t.peekChar() == '%') {
	    t.getChar();
	    return TokenPunct.MOD;
	}

	if (t.peekChar() == '!') {
	    t.getChar();
	    if (t.peekChar() == '=') {
		t.getChar();
		return TokenPunct.NE;
	    } else {
		return TokenPunct.NOT;
	    }
	}

	if (t.peekChar() == '{') {
	    t.getChar();
	    return TokenPunct.LBRACE;
	}

	if (t.peekChar() == '}') {
	    t.getChar();
	    return TokenPunct.RBRACE;
	}

	if (t.peekChar() == '[') {
	    t.getChar();
	    return TokenPunct.LBRACK;
	}

	if (t.peekChar() == ']') {
	    t.getChar();
	    return TokenPunct.RBRACK;
	}

	if (t.peekChar() == '(') {
	    t.getChar();
	    return TokenPunct.LPAREN;
	}

	if (t.peekChar() == ')') {
	    t.getChar();
	    return TokenPunct.RPAREN;
	}

	if (t.peekChar() == '.') {
	    t.getChar();
	    if (t.peekChar() == '.') {
		t.getChar();
		return TokenPunct.DOTDOT;
	    }
            return TokenPunct.DOT;
	}

	if (t.peekChar() == ',') {
	    t.getChar();
	    return TokenPunct.COMMA;
	}

	if (t.peekChar() == '?') {
	    t.getChar();
	    return TokenPunct.QMARK;
	}

	return null;
    }

    public void asHTML (Output o)
    {
	if (punct.equals("[") || punct.equals("]") ||
	    punct.equals("(") || punct.equals(")") ||
	    punct.equals("{") || punct.equals("}")) {

	    o.write("<span class=\"b\">" + punct + "</span>");
	} else {
	    o.write("<span class=\"p\">" + punct + "</span>");
	}
    }

    public void asS2 (Output o)
    {
	o.write(punct);
    }

}


