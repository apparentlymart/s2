package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;

public class NodeTerm extends Node
{
    int type = 0;

    public final static int INTEGER = 1;
    TokenIntegerLiteral tokInt;

    public final static int STRING = 2;
    TokenStringLiteral tokStr;

    public final static int BOOL = 3;
    boolean boolValue;

    public final static int VARREF = 4;
    NodeVarRef var;

    public final static int SUBEXPR = 5;
    public final static int DEFINEDTEST = 6;
    public final static int SIZEFUNC = 7;
    public final static int REVERSEFUNC = 8;
    NodeExpr subExpr;
    Type subType;      // for backend, set by getType()

    public final static int NEW = 9;
    TokenIdent newClass;

    public final static int FUNCCALL = 10;
    public final static int METHCALL = 11;
    TokenIdent funcIdent;
    String funcClass;      // null or classname of the method call
    NodeArguments funcArgs;
    boolean funcBuiltin;   // is this function call a builtin?  
                           // (if so, don't use vtable)
    boolean parentMethod;  // is this a method call on a super class?  if so,
                           // can't optimize method call since instance class won't
                           // necessarily be known until run-time (without a lot of analysis)
    boolean callFromSet;    // if so, then lookup by funcID, if 
    String funcID;         // used by backend; set after getType()
    String funcID_noclass; 
    int funcNum;    // used by perl backend for function vtables
    
    public static boolean canStart (Tokenizer toker) throws Exception
    {
	Token t = toker.peek();
	if (t instanceof TokenIntegerLiteral ||
	    t instanceof TokenStringLiteral ||
	    t instanceof TokenIdent ||
	    t.equals(TokenPunct.LPAREN) ||
	    t.equals(TokenPunct.DOLLAR) ||
	    t.equals(TokenKeyword.DEFINED) ||
	    t.equals(TokenKeyword.TRUE) ||
	    t.equals(TokenKeyword.FALSE) ||
	    t.equals(TokenKeyword.NEW) ||
	    t.equals(TokenKeyword.SIZE) ||
	    t.equals(TokenKeyword.REVERSE)
	    )
	    return true;
	return false;    
    }

    public Type getType (Checker ck) throws Exception
    {
	if (type == INTEGER) return Type.INT;
	if (type == STRING)  return Type.STRING;
	if (type == SUBEXPR) return subExpr.getType(ck);
	if (type == BOOL) return Type.BOOL;

	if (type == DEFINEDTEST) {
	    System.err.println("FIXME: check type of defined expression");
	    return Type.BOOL;
	}
	if (type == SIZEFUNC) {
	    subType = subExpr.getType(ck);

	    // reverse a string
	    if (subType.equals(Type.STRING)) 
		return Type.INT;

	    // reverse an array
	    if (subType.isArrayOf())
		return Type.INT;

	    // complain
	    throw new Exception("Can't use size on expression that's "+
				"not a string or array at "+getFilePos());

	}
	if (type == REVERSEFUNC) {
	    subType = subExpr.getType(ck);

	    // reverse a string
	    if (subType.equals(Type.STRING)) 
		return Type.STRING;

	    // reverse an array
	    if (subType.isArrayOf())
		return subType;

	    // complain
	    throw new Exception("Can't use reverse on expression that's "+
				"not a string or array at "+getFilePos());
	}
	
	if (type == NEW) {
	    String clas = newClass.getIdent();
	    NodeClass nc = ck.getClass(clas);
	    if (nc == null) {
		throw new Exception("Can't instantiate unknown class at "+
				    getFilePos());
	    }
	    return new Type(clas);
	}

	if (type == VARREF) {
	    return var.getType(ck);
	}

	if (type == METHCALL || type == FUNCCALL) {

	    // find the classname of the variable the method was being called on
	    if (type == METHCALL) {
		Type vartype = var.getType(ck);
		if (! vartype.isSimple()) {
		    throw new Exception("Cannot call a method on an array or hash of "+
					"objects at "+getFilePos());
		}
		funcClass = vartype.toString();

		NodeClass methClass = ck.getClass(funcClass);
		if (methClass == null) {
		    throw new Exception("Can't call a method on an instance of an "+
					"undefined class at "+getFilePos());
		}

		if (ck.hasDerClasses(funcClass)) 
		    parentMethod = true;
	    }
	    
	    funcID = Checker.functionID(funcClass, funcIdent.getIdent(),
					funcArgs.typeList(ck));
	    funcBuiltin = ck.isFuncBuiltin(funcID);

	    // and remember the funcID without a class for use later when
	    // we have to generate a funcID at run-time by concatenating
	    // this to the end of a $instance->{'_type'}
	    funcID_noclass = Checker.functionID(null, funcIdent.getIdent(),
						funcArgs.typeList(ck));

	    Type t = ck.functionType(funcID);
	    if (! funcBuiltin) 
		funcNum = ck.functionNum(funcID);
	    if (t == null) {
	      throw new Exception("Unknown function "+funcID+" at "+
				  funcIdent.getFilePos());
	    } 
	    return t;
	}

	throw new Exception("ERROR: unknown NodeTerm type");	
    }
    
    public boolean isLValue () 
    {
	if (type == VARREF) return true;
	if (type == SUBEXPR) {
	    return subExpr.isLValue();
	}
        return false;
    }

    public boolean makeAsString(Checker ck)
    {
	if (type == VARREF) {
	    try {
		Type t = var.getType(ck);
		if (t.isSimple()) {
		    String bt = t.baseType();

		    // class has .toString() method
		    if (ck.classHasToString(bt)) {
			// let's change this VARREF into a METHCALL!
			// warning: ugly hacks ahead...
			type = METHCALL;
			funcIdent = new TokenIdent("toString");
			funcClass = bt;
			funcArgs = (NodeArguments) 
			    NodeArguments.makeEmptyArgs();
			funcID_noclass = "toString()";
			funcID = bt + "::" + funcID_noclass;
			funcBuiltin = ck.isFuncBuiltin(funcID);
			funcNum = ck.functionNum(funcID);
			if (ck.hasDerClasses(funcClass)) 
			    parentMethod = true;
	
			return true;
		    }

		    // class has $.asString string member
		    if (ck.classHasAsString(bt)) {
			var.useAsString();
			return true;
		    }
		}
	    } catch (Exception e) {
		return false;
	    }
	}
	return false;
    }

    public static NodeTerm makeStringCtorCall (String type, String val)
    {
	NodeTerm nt = new NodeTerm();
	nt.type = FUNCCALL;
	nt.funcIdent = new TokenIdent(type);
	nt.funcClass = type;
	nt.funcArgs = NodeArguments.makeEmptyArgs();
	nt.funcArgs.addArg(new NodeExpr(makeStringLiteral(val)));
	nt.callFromSet = true; // force get_func_num lookup in asPerl
	return nt;
    }

    public static NodeTerm makeStringLiteral (String val)
    {
	NodeTerm nt = new NodeTerm();
	nt.type = STRING;
	nt.tokStr = new TokenStringLiteral(val);
	return nt;
    }
    
    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeTerm nt = new NodeTerm();

	Token t = toker.peek();

	// integer literal
	if (t instanceof TokenIntegerLiteral) {
	    nt.type = NodeTerm.INTEGER;
	    nt.tokInt = (TokenIntegerLiteral) nt.eatToken(toker);	    
	    return nt;
	}

	// boolean literal
	if (t.equals(TokenKeyword.TRUE) || t.equals(TokenKeyword.FALSE)) {
	    nt.type = NodeTerm.BOOL;
	    nt.boolValue = t.equals(TokenKeyword.TRUE);
	    nt.eatToken(toker);
	    return nt;
	}

	// string literal
	if (t instanceof TokenStringLiteral) {
	    TokenStringLiteral ts = (TokenStringLiteral) t;
	    int ql = ts.getQuotesLeft();
	    int qr = ts.getQuotesRight();

	    // interpolated string literal (turn into a subexpr)
	    if (qr != 0) {
		// whole string literal
		nt.type = NodeTerm.STRING;
		nt.tokStr = (TokenStringLiteral) nt.eatToken(toker);
		return nt;
	    } else {
		LinkedList toklist = new LinkedList();

		nt.type = NodeTerm.STRING;
		nt.tokStr = (TokenStringLiteral) nt.eatToken(toker);
		toklist.add(nt.tokStr.clone());  // cloned before it's changed.
		nt.tokStr.setQuotesRight(ql);
		Node lhs = nt;

		boolean loop = true;
		while (loop) {
		    Node rhs = null;
		    Token tok = toker.peek();
		    if (tok instanceof TokenStringLiteral) {
			rhs = new NodeTerm();
			NodeTerm rhsnt = (NodeTerm) rhs;
			ts = (TokenStringLiteral) tok;
			rhsnt.type = NodeTerm.STRING;
			rhsnt.tokStr = (TokenStringLiteral) rhsnt.eatToken(toker);
			toklist.add(rhsnt.tokStr.clone());  // cloned before it's changed.

			if (ts.getQuotesRight() == ql) {
			    loop = false;
			}
			ts.setQuotesRight(ql);
			ts.setQuotesLeft(ql);
		    }
		    else if (tok.equals(TokenPunct.DOLLAR)) {
			rhs = NodeTerm.parse(toker);
			toklist.add(rhs);
		    }
		    else {
			throw new Exception("Error parsing "+
					    "interpolated string.");
		    }

		    // don't make a sum out of a blank string on either side
		    boolean join = true;
		    if (lhs instanceof NodeTerm) {
			NodeTerm lhst = (NodeTerm) lhs;			
			if (lhst.type == STRING &&
			    lhst.tokStr.getString().length() == 0) {
			    lhs = rhs;
			    join = false;
			}
		    }
		    if (rhs instanceof NodeTerm) {
			NodeTerm rhst = (NodeTerm) rhs;
			if (rhst.type == STRING &&
			    rhst.tokStr.getString().length() == 0) {
			    join = false;
			}
		    }
		    if (join) {
			lhs = new NodeSum(lhs, TokenPunct.PLUS, rhs);
		    }
		}

		lhs.setTokenList(toklist);
		return lhs;
	    } 
	}

	// Sub-expression (in parenthesis)
	if (t.equals(TokenPunct.LPAREN)) {
	    nt.type = NodeTerm.SUBEXPR;
	    nt.setStart(nt.eatToken(toker));
	    
	    nt.subExpr = (NodeExpr) NodeExpr.parse(toker);
	    nt.addNode(nt.subExpr);

	    nt.requireToken(toker, TokenPunct.RPAREN);
	    return nt;
	}

	// defined test
	if (t.equals(TokenKeyword.DEFINED)) {
	    nt.type = NodeTerm.DEFINEDTEST;
	    nt.eatToken(toker);
	    nt.subExpr = (NodeExpr) NodeExpr.parse(toker);
	    nt.addNode(nt.subExpr);
	    return nt;
	}

	// reverse function
	if (t.equals(TokenKeyword.REVERSE)) {
	    nt.type = NodeTerm.REVERSEFUNC;
	    nt.eatToken(toker);
	    nt.subExpr = (NodeExpr) NodeExpr.parse(toker);
	    nt.addNode(nt.subExpr);
	    return nt;
	}

	// size function
	if (t.equals(TokenKeyword.SIZE)) {
	    nt.type = NodeTerm.SIZEFUNC;
	    nt.eatToken(toker);
	    nt.subExpr = (NodeExpr) NodeExpr.parse(toker);
	    nt.addNode(nt.subExpr);
	    return nt;
	}

	// new 
	if (t.equals(TokenKeyword.NEW)) {
	    nt.type = NodeTerm.NEW;
	    nt.eatToken(toker);
	    nt.newClass = nt.getIdent(toker);
	    return nt;
	}

	// VarRef
	if (t.equals(TokenPunct.DOLLAR)) {
	    nt.type = VARREF;
	    nt.var = (NodeVarRef) NodeVarRef.parse(toker);
	    nt.addNode(nt.var);

	    // check for -> after, like: $object->method(arg1, arg2, ...)
	    if (toker.peek().equals(TokenPunct.DEREF)) {
		nt.eatToken(toker);
		nt.type = METHCALL;
		// don't return... parsing continues below.
	    } else {
		return nt;	    
	    }
	}

	// function/method call
	if (t instanceof TokenIdent || nt.type == METHCALL) {
	    if (nt.type != METHCALL) nt.type = FUNCCALL;

	    nt.funcIdent = nt.getIdent(toker);
	    nt.funcArgs = (NodeArguments) NodeArguments.parse(toker);
	    nt.addNode(nt.funcArgs);

	    return nt;	    
	}
	
	throw new Exception("Can't finish parsing NodeTerm at " +
			    toker.locationString() + 
			    ", toker.peek() = " + t.toString());
    }

    public void asS2 (Indenter o)
    {
	if (type == INTEGER) {
	    tokInt.asS2(o);
	    return;
	}
	if (type == STRING) {
	    tokStr.asS2(o);
	    return;
	}
	if (type == BOOL) {
	    if (boolValue) 
		o.write("true");
	    else
		o.write("false");
	    return;
	}
	if (type == SUBEXPR) {
	    o.write("(");
	    subExpr.asS2(o);
	    o.write(")");
	    return;
	}
	if (type == NEW) {
	    o.write("new ");
	    o.write(newClass.getIdent());
	    return;
	}
	if (type == DEFINEDTEST) {
	    o.write("defined ");
	    subExpr.asS2(o);
	    return;
	}
	if (type == SIZEFUNC) {
	    o.write("size ");
	    subExpr.asS2(o);
	    return;
	}
	if (type == REVERSEFUNC) {
	    o.write("reverse ");
	    subExpr.asS2(o);
	    return;
	}
	if (type == VARREF || type == METHCALL) {
	    var.asS2(o);
	}
	if (type == METHCALL) {
	    o.write("->");
	}
	if (type == METHCALL || type == FUNCCALL) {
	    o.write(funcIdent.getIdent());
	    funcArgs.asS2(o);
	}
	if (type == VARREF || type == METHCALL || type == FUNCCALL)
	    return;
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {
	if (type == INTEGER) {
	    tokInt.asPerl(bp, o);
	    return;
	}
	if (type == STRING) {
	    tokStr.asPerl(bp, o);
	    return;
	}
	if (type == BOOL) {
	    if (boolValue) 
		o.write("1");
	    else
		o.write("0");
	    return;
	}
	if (type == SUBEXPR) {
	    o.write("(");
	    subExpr.asPerl(bp, o);
	    o.write(")");
	    return;
	}
	if (type == NEW) {
	    o.write("{'_type'=>" +
		    bp.quoteString(newClass.getIdent())+
		    "}");
	    return;
	}
	if (type == DEFINEDTEST) {
	    o.write("defined(");
	    subExpr.asPerl(bp, o);
	    o.write(")");
	    return;
	}
	if (type == REVERSEFUNC) {
	    if (subType.isArrayOf()) {
		o.write("[reverse(");
		o.write("@{");
		subExpr.asPerl(bp, o);
		o.write("})");
		o.write("]");
	    } else if (subType.equals(Type.STRING)) {
		o.write("reverse(");
		subExpr.asPerl(bp, o);
		o.write(")");
	    }
	    return;
	}
	if (type == SIZEFUNC) {
	    if (subType.equals(Type.STRING)) {
		o.write("length(");
		subExpr.asPerl(bp, o);
		o.write(")");
	    } 
	    else if (subType.isArrayOf()) {
		o.write("scalar(@{");
		subExpr.asPerl(bp, o);
		o.write("})");
	    }
	    return;
	}
	if (type == VARREF) {
	    var.asPerl(bp, o);
	    return;
	}

	if (type == FUNCCALL || type == METHCALL) {

	    boolean funcDumped = false;

	    // builtin functions can be optimized.
	    if (funcBuiltin) {
		// these built-in functions can be inlined.
		if (funcID.equals("string(int)")) {
		    funcArgs.asPerl(bp, o, false);
		    return;
		}
		if (funcID.equals("int(string)")) {
		    // cast from string to int by adding zero to it
		    o.write("(0+");
		    funcArgs.asPerl(bp, o, false);
		    o.write(")");
		    return;
		}

		// otherwise, call the builtin function (avoid a layer
		// of indirection), unless it's for a class that has
		// children (won't know until run-time which class to call)
		if(funcClass == null || (funcClass != null && ! parentMethod)) {
		    o.write("S2::Builtin::");
		    if (funcClass != null) {
			o.write(funcClass + "__");
		    }
		    o.write(funcIdent.getIdent());
		    funcDumped = true;
		}
	    }
	    
	    if (funcDumped == false) {
		if (callFromSet) {
		    o.write("$_ctx->[VTABLE]->{get_func_num(");
		    o.write(bp.quoteString(funcID));
		    o.write(")}->");
		} else if (parentMethod) {
		    o.write("$_ctx->[VTABLE]->{get_func_num(");
		    var.asPerl(bp, o);
		    o.write("->{'_type'}.");
		    o.write(bp.quoteString("::"+funcID_noclass));
		    o.write(")}->");
		} else {
		    o.write("$_ctx->[VTABLE]->{$_l2g_func{"+funcNum+"}}->");
		}
	    }

	    o.write("($_ctx, ");

	    // this pointer
	    if (type == METHCALL) {
		var.asPerl(bp, o);
		o.write(", ");
	    }

	    funcArgs.asPerl(bp, o, false);

	    o.write(")");
	    return;
	}
    }
    

}
