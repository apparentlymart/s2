package danga.s2;

public class NodeSet extends Node
{
    String key;
    NodeExpr value;

    public static boolean canStart (Tokenizer toker) throws Exception
    {
	if (toker.peek().equals(TokenKeyword.SET))
	    return true;
	return false;
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeText nkey;
	NodeSet ns = new NodeSet();
	
	ns.setStart(ns.requireToken(toker, TokenKeyword.SET));

	nkey = (NodeText) NodeText.parse(toker);
	ns.addNode(nkey);

	ns.requireToken(toker, TokenPunct.ASSIGN);

	ns.value = (NodeExpr) NodeExpr.parse(toker);
	ns.addNode(ns.value);

	ns.requireToken(toker, TokenPunct.SCOLON);

	ns.key = nkey.getText();

	return ns;
    }

    public void asS2 (Indenter o)
    {
	o.tabwrite("set ");
	o.write(Backend.quoteString(key));
	o.write(" = ");
        value.asS2(o);
	o.writeln(";");
    }

    public void check (Layer l, Checker ck) throws Exception
    {
	Type ltype = ck.propertyType(key);

        ck.setInFunction(false);

	// check to see that the thing we're setting exists
	if (ltype == null) {
	    throw new Exception("Can't set non-existent property '" + key + "' at " +
				getFilePos());
	}

        Type rtype = value.getType(ck, ltype);
        
        if (! ltype.equals(rtype)) {
            throw new Exception("Property value is of wrong type at "+getFilePos());
        }

	// simple case... assigning a primitive
	if (ltype.isPrimitive()) {
            // TODO: check that value.isLiteral()
            // TODO: check value's type matches
	    return;
	}

        Type base = new Type(ltype.baseType());
        if (base.isPrimitive()) {
            return;
        } else if (ck.getClass(ltype.baseType()) == null) {
            throw new Exception("Can't set property of unknown type at "+
                                getFilePos());
        }

	// more complex case... calling a constructor to generate
	// the value
	//nodevalue = NodeTerm.makeStringCtorCall(type.baseType(), val);
	//nodevalue.getType(ck);
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {

	o.tabwrite("register_set("+
		   bp.getLayerIDString() + "," +
		   bp.quoteString(key) + ",");
	value.asPerl(bp, o);
        o.writeln(");");
        return;

	// Second case: setting a property that's a class, so code
	// must be run to invoke the class constructor with that string.
	// however, the raw string value still needs to be accessible easily
	// to things like the GUI configurator, so the "value" here is
	// really an arrayref with [ realvalue, coderef ].
	/*
	o.writeln("[" + bp.quoteString(val) + ", sub {");
	o.tabIn();
	o.tabwriteln("my $_ctx = shift;");
	o.tabwrite("return ");
	nodevalue.asPerl(bp, o);
	o.writeln(";");
	o.tabOut();
	o.tabwriteln("}]);");
        */
    }

};
