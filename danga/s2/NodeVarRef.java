package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;

public class NodeVarRef extends Node
{
    public final static int LOCAL = 1;
    public final static int OBJECT = 2;
    public final static int PROPERTY = 3;

    class Deref {
	public char type;
	public NodeExpr expr;
    }

    class VarLevel {
	public String var;
	public LinkedList derefs;
    }

    LinkedList levels;
    
    boolean braced;
    int type = LOCAL;

    boolean useAsString = false;

    public static boolean canStart (Tokenizer toker) throws Exception
    {
	if (toker.peek().equals(TokenPunct.DOLLAR))
	    return true;
	return false;			  
    }
    
    public static Node parse (Tokenizer tokermain) throws Exception
    {
	// voo-doo so tokenizer won't continue parsing a string
	// if we're in a string and trying to parse interesting things
	// involved in a VarRef:

	NodeVarRef n = new NodeVarRef();
	n.levels = new LinkedList();
	
	n.setStart(n.requireToken(tokermain, TokenPunct.DOLLAR, false));

	Tokenizer toker = tokermain.inString == 0 ? 
	    tokermain : tokermain.getVarTokenizer();	
	
	if (toker.peekChar() == '{') {
	    n.requireToken(toker, TokenPunct.LBRACE, false);
	    n.braced = true;
	} else {
	    n.braced = false;
	}

	if (toker.peekChar() == '.') {
	    n.requireToken(toker, TokenPunct.DOT, false);
	    n.type = OBJECT;
	} else if (toker.peekChar() == '*') {
	    n.requireToken(toker, TokenPunct.MULT, false);
	    n.type = PROPERTY;
	} 

	boolean requireDot = false;
	
	// only peeking at characters, not tokens, otherwise
	// we could force tokens could be created in the wrong 
	// context.  
	while (TokenIdent.canStart(toker) ||
	       toker.peekChar() == '.') {
	    
	    if (requireDot) {
		n.requireToken(toker, TokenPunct.DOT, false);
	    } else {
		requireDot = true;
	    }
	    
	    TokenIdent ident = (TokenIdent) n.getIdent(toker, true, false);

	    VarLevel vl = n.new VarLevel();
	    vl.var = ident.getIdent();
	    vl.derefs = new LinkedList();

	    // more preventing of token peeking:
	    while (toker.peekChar() == '[' ||
		   toker.peekChar() == '{') {
		
		Deref dr = n.new Deref();
		Token t = n.eatToken(toker, false);
		
		if (t.equals(TokenPunct.LBRACK)) {
		    dr.type = '[';
		    n.addNode(dr.expr = (NodeExpr) NodeExpr.parse(toker));
		    n.requireToken(toker, TokenPunct.RBRACK, false);
		} else if (t.equals(TokenPunct.LBRACE)) {
		    dr.type = '{';
		    n.addNode(dr.expr = (NodeExpr) NodeExpr.parse(toker));
		    n.requireToken(toker, TokenPunct.RBRACE, false);
		} else {
		    throw new Exception("shouldn't get here");
		}
		
		vl.derefs.add(dr);
	    }

	    n.levels.add(vl);
	} // end while

        // did we parse just $ ?
        if (n.levels.size() == 0) {
            throw new Exception("Malformed variable reference at "+
                                n.getFilePos());
        }

	if (n.braced) {
	    // false argument necessary to prevent peeking at token
	    // stream while it's in the interpolated variable parsing state,
	    // else the string text following the variable would be
	    // treated as if it were outside the string.
	    n.requireToken(toker, TokenPunct.RBRACE, false);
	}

	// now we must skip white space that requireToken above would've
	// done had we not told it not to, but not if the main tokenizer
	// is in a quoted string
	if (tokermain.inString == 0) {
	    n.skipWhite(toker);
	}

	return n;
    }

    // if told by NodeTerm.java, add another varlevel to point to
    // this object's $.as_string
    public void useAsString ()
    {
	VarLevel vl = new VarLevel();
	vl.var = "as_string";
	vl.derefs = new LinkedList();  // empty
	levels.add(vl);
    }

    public boolean isHashElement () 
    {
	if (type != OBJECT && type != LOCAL)
	    return false;

	// need to get the last deref of the last varlevel
	if (levels.size() == 0) 
	    return false;
	VarLevel l = (VarLevel) levels.getLast();
	if (l.derefs.size() == 0)
	    return false;
	Deref d = (Deref) l.derefs.getLast();
	return d.type == '{';	
    }

    public Type getType (Checker ck, Type wanted) throws Exception
    {
        Type t = getType(ck);
        if (wanted == null) return t;
        if (! wanted.equals(Type.STRING)) return t;

        String type = t.toString();
        if (ck.classHasAsString(type)) {
            useAsString = true;
            return Type.STRING;
        }
        return t;
    }

    public Type getType (Checker ck) throws Exception
    {
	// must have at least reference something.
	if (levels.size() == 0) return null;

	ListIterator levi = levels.listIterator();
	VarLevel lev = (VarLevel) levi.next();

	Type vart = null;

	// properties
	if (type == PROPERTY) {
            vart = ck.propertyType(lev.var);
            if (vart == null)
                throw new Exception("Unknown property at "+getFilePos());
            vart = (Type) vart.clone();
	}

	// local variables.
	if (type == LOCAL) {
	    vart = (Type) ck.localType(lev.var);
	    if (vart == null) {
		throw new Exception("Unknown local variable $"+lev.var+" at "+
				    getFilePos());
	    }
	}
        
        // properties & locals
        if (type == PROPERTY || type == LOCAL) {
            vart = (Type) vart.clone();  // since we'll be modifying it

	    // dereference [] and {} stuff
	    doDerefs(ck, lev.derefs, vart);

	    // if no more levels, return now.  otherwise deferencing
	    // happens below.
	    if (! levi.hasNext()) {
		return vart;
	    } else {
		lev = (VarLevel) levi.next();
	    }
        }

	// initialize the name of the current object
	if (type == OBJECT) {
            String curclass = ck.getCurrentFunctionClass();
            if (curclass == null) {
                throw new Exception("Can't reference member variable in non-method "+
                                    "function at "+getFilePos());
            }
	    vart = new Type(curclass);
	}

        while (lev != null) {
            NodeClass nc = ck.getClass(vart.toString());
            if (nc == null)
                throw new Exception("Can't use members of undefined class "+vart+" at "+getFilePos());
            vart = nc.getMemberType(lev.var);
            if (vart == null) {
                throw new Exception("Can't find member '"+lev.var+"' in '"+nc.getName()+"'");
            }
            vart = (Type) vart.clone();
            
            // dereference [] and {} stuff
            doDerefs(ck, lev.derefs, vart);
            
            lev = levi.hasNext() ? (VarLevel) levi.next() : null;
        }
        
        return vart;
    }

    private void doDerefs (Checker ck, LinkedList derefs, Type vart) throws Exception
    {
	// remove [] and {} references
	ListIterator lm = derefs.listIterator();
	while (lm.hasNext()) {
	    Deref d = (Deref) lm.next();
	    Type et = d.expr.getType(ck);		
	    if (d.type == '{') {
		if (! vart.isHashOf()) {
		    throw new Exception("Can't dereference a non-hash as a hash at "+
					getFilePos());
		}
		if (! (et.equals(Type.STRING) || et.equals(Type.INT))) {
		    throw new Exception("Must deference a hash with a string or "+
					"int, not a "+et+" at "+getFilePos());
		}
		vart.removeMod();  // not a hash anymore
	    } else if (d.type == '[') {
		if (! vart.isArrayOf()) {
		    throw new Exception("Can't dereference a non-array as an array at "+
					getFilePos());
		}
		if (! et.equals(Type.INT)) {
		    throw new Exception("Must deference an array with an integer, "+
					"not a "+et+" at "+getFilePos());
		}
		vart.removeMod();  // not an array anymore
	    }
	}
    }

    private String typeChar () {
        if (type == OBJECT) return ".";
        if (type == PROPERTY) return "*";
        return "";
    }

    public void asS2 (Indenter o) 
    {
	o.write("$" + typeChar());
	ListIterator li = levels.listIterator(0);
	boolean first = true;
	while (li.hasNext()) {
	    VarLevel lev = (VarLevel) li.next();
	    if (! first) o.write("."); else first = false;
	    o.write(lev.var);
	    
	    ListIterator dli = lev.derefs.listIterator(0);
	    while (dli.hasNext()) {
		Deref d = (Deref) dli.next();
		if (d.type == '[') { o.write("["); }
		if (d.type == '{') { o.write("{"); }
		d.expr.asS2(o);
		if (d.type == '[') { o.write("]"); }
		if (d.type == '{') { o.write("}"); }
	    }
	} // end levels
    }

    // is this variable $super ?
    public boolean isSuper ()
    {
        if (type != LOCAL) return false;
        if (levels.size() > 1) return false;
        VarLevel v = (VarLevel) levels.getFirst();
        return (v.var.equals("super") &&
                v.derefs.size() == 0);
    }

    public void asPerl (BackendPerl bp, Indenter o) 
    {
	ListIterator li = levels.listIterator();
	boolean first = true;

	if (type == LOCAL) {
	    o.write("$");
	} else if (type == OBJECT) {
	    o.write("$this");
	} else if (type == PROPERTY) {
	    o.write("$_ctx->[PROPS]");
	    first = false;
	}
	while (li.hasNext()) {
	    VarLevel lev = (VarLevel) li.next();
	    if (! first || type == OBJECT) { 
		o.write("->{'" + lev.var + "'}");
	    } else {
                String v = lev.var;
                if (first && type == LOCAL && lev.var.equals("super"))
                    v = "this";
		o.write(v);
		first = false;
	    }
	    
	    ListIterator dli = lev.derefs.listIterator(0);
	    while (dli.hasNext()) {
		o.write("->");
		Deref d = (Deref) dli.next();
		if (d.type == '[') { o.write("["); }
		if (d.type == '{') { o.write("{"); }
		d.expr.asPerl(bp, o);
		if (d.type == '[') { o.write("]"); }
		if (d.type == '{') { o.write("}"); }
	    }
	} // end levels

        if (useAsString) {
            o.write("->{'as_string'}");
        }
    }

};
