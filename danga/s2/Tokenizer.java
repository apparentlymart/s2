package danga.s2;

import java.io.InputStream;

public class Tokenizer 
{
    Token peekedToken;
    Tokenizer masterTokenizer;
    Scanner sc;

    // these are public for the Tokens to access when scanning:  (no 'friend' classes in Java.  :/)
    public int inString;     // can be 0, 1, or 3.  (string types of none, normal, triple quote)
  
    boolean varToker = false;

    public Tokenizer (InputStream is)
    {
        if (is != null) sc = new Scanner(is);
	inString = 0;
	peekedToken = null;
	masterTokenizer = this;
    }

    public Tokenizer getVarTokenizer() throws Exception
    {
	Tokenizer vt = new Tokenizer(null); // null unimportant--- setting scanner later
	vt.inString = 0;  // note: we probably _are_ in a string.
        vt.varToker = true;

	// clone everything else:
	vt.masterTokenizer = masterTokenizer;
	vt.sc = sc;

	// but don't clone this...
	if (peekedToken != null) {
	    throw new Exception("Request to instantiate sub-tokenizer failed because "+
				"master tokenizer has a peeked token loaded already.");
	}

	return vt;
    }

    public void release () throws Exception
    {
	if (peekedToken != null) {
	    throw new Exception("Sub-tokenizer had a peeked token when releasing.");
	}
    }

    public Token peek () throws Exception
    {
	if (peekedToken == null) {
	    peekedToken = getToken();
	}
	return peekedToken;
    }

    public Token getToken () throws Exception
    {
	if (peekedToken != null) {
	    Token t = peekedToken;
	    peekedToken = null;
	    return t;
	}

	char nextChar = sc.peek();

	if (nextChar == (char) -1) {
            if (sc.getBogusFlag())
                throw new Exception("Malformed source encoding.  (should be UTF-8)");
	    return null;
	}

	FilePos pos = getPos();
	Token nxtoken = makeToken();
	nxtoken.pos = pos;

	return nxtoken;
    }

    public FilePos getPos () {
        return new FilePos(sc.line, sc.col);
    }

    private Token makeToken () throws Exception
    {
	char nextChar = sc.peek();
	
	// this has to be before the string literal parsing.
	if (nextChar == '$') {
	    return TokenPunct.scan(this);
	}

	if (inString != 0) { 
	    return TokenStringLiteral.scan(this);
	}
    
	if (nextChar == ' ' || nextChar == '\t' ||
	    nextChar == '\n' || nextChar == '\r') {
	    return TokenWhitespace.scan(this);
	}
    
	if (TokenIdent.canStart(this)) {
	    return TokenIdent.scan(this);
	}

	if (nextChar >= '0' && nextChar <= '9') {
	    return TokenIntegerLiteral.scan(this);
	}
    
	if (nextChar == '<' || nextChar == '>' ||
	    nextChar == '=' || nextChar == '!' ||
	    nextChar == ';' || nextChar == ':' ||
	    nextChar == '+' || nextChar == '-' ||
	    nextChar == '*' || nextChar == '/' ||
	    nextChar == '&' || nextChar == '|' ||
	    nextChar == '{' || nextChar == '}' ||
	    nextChar == '[' || nextChar == ']' ||
	    nextChar == '(' || nextChar == ')' ||
	    nextChar == '.' || nextChar == ',' ||
	    nextChar == '?' || nextChar == '%' || 
	    false) {
	    return TokenPunct.scan(this);
	}
    
	if (nextChar == '#') {
	    return TokenComment.scan(this);
	}
    
	if (nextChar == '"') {
	    return TokenStringLiteral.scan(this);
	}
    
	throw new Exception("Parse error!  Unknown character '" + nextChar + 
			    "' (" + (new Integer((int)nextChar)).toString() + ") encountered at " +
                            locationString());
    }
  
    public String locationString () {
	return sc.locationString();
    }

    public char peekChar () {
	return sc.peek();
    }

    public char getChar () {
	return sc.getChar();
    }

    public char getRealChar () throws Exception {
	return sc.getRealChar();
    }

    public void forceNextChar (char ch) {
	sc.forceNextChar(ch);
    }

}


