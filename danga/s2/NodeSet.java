package danga.s2;

public class NodeSet extends Node
{
    String key;
    String val;
    Type type;

    NodeTerm nodevalue;

    public static boolean canStart (Tokenizer toker) throws Exception
    {
	if (toker.peek().equals(TokenKeyword.SET))
	    return true;
	return false;
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeText nkey;
	NodeText nval;
	NodeSet ns = new NodeSet();
	
	ns.setStart(ns.requireToken(toker, TokenKeyword.SET));

	nkey = (NodeText) NodeText.parse(toker);
	ns.addNode(nkey);

	ns.requireToken(toker, TokenPunct.ASSIGN);

	nval = (NodeText) NodeText.parse(toker);
	ns.addNode(nval);

	ns.requireToken(toker, TokenPunct.SCOLON);

	ns.key = nkey.getText();
	ns.val = nval.getText();

	return ns;
    }

    public void asS2 (Indenter o)
    {
	o.tabwrite("set ");
	o.write(Backend.quoteString(key));
	o.write(" = ");
	o.write(Backend.quoteString(val));
	o.writeln(";");
    }

    public void check (Layer l, Checker ck) throws Exception
    {
	type = ck.propertyType(key);

	// check to see that the thing we're setting exists
	if (type == null) {
	    throw new Exception("Can't set non-existent property '" + key + "' at " +
				getFilePos());
	}

	// simple case... assigning a primitive
	if (type.equals(Type.INT) || type.equals(Type.BOOL) ||
	    type.equals(Type.STRING)) {
	    nodevalue = null;
	    return;
	}

        if (ck.getClass(type.baseType()) == null) {
            throw new Exception("Can't set property of unknown type at "+
                                getFilePos());
        }

	// more complex case... calling a constructor to generate
	// the value
	nodevalue = NodeTerm.makeStringCtorCall(type.baseType(), val);
	nodevalue.getType(ck);
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {

	o.tabwrite("register_set("+
		   bp.getLayerIDString() + "," +
		   bp.quoteString(key) + ",");
	
	// two cases to handle here:

	// Simple case, when setting a property of a primitive type
	if (nodevalue == null) {
	    o.writeln(bp.quoteString(val) + ");");
	    return;
	}

	// Second case: setting a property that's a class, so code
	// must be run to invoke the class constructor with that string.
	// however, the raw string value still needs to be accessible easily
	// to things like the GUI configurator, so the "value" here is
	// really an arrayref with [ realvalue, coderef ].
	
	o.writeln("[" + bp.quoteString(val) + ", sub {");
	o.tabIn();
	o.tabwriteln("my $_ctx = shift;");
	o.tabwrite("return ");
	nodevalue.asPerl(bp, o);
	o.writeln(";");
	o.tabOut();
	o.tabwriteln("}]);");

    }

};
