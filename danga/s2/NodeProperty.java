package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;

public class NodeProperty extends Node
{
    NodeNamedType nt;
    LinkedList pairs;
    boolean builtin = false;

    public static boolean canStart (Tokenizer toker) throws Exception
    {
	if (toker.peek().equals(TokenKeyword.PROPERTY))
	    return true;
	return false;
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeProperty n = new NodeProperty();
	n.pairs = new LinkedList();

	n.requireToken(toker, TokenKeyword.PROPERTY);

	if (toker.peek().equals(TokenKeyword.BUILTIN)) {
	    n.builtin = true;
	    n.eatToken(toker);
	}

	n.addNode(n.nt = (NodeNamedType) NodeNamedType.parse(toker));

	Token t = toker.peek();
	if (t.equals(TokenPunct.SCOLON)) {
	    n.eatToken(toker);
	    return n;
	}

	n.requireToken(toker, TokenPunct.LBRACE);
	while (NodePropertyPair.canStart(toker)) {
	    Node pair = NodePropertyPair.parse(toker);
	    n.tokenlist.add(pair);
	    n.pairs.add(pair);
	}
	n.requireToken(toker, TokenPunct.RBRACE);

	return n;
    }

    public void check (Layer l, Checker ck) throws Exception 
    {
	String name = nt.getName();
	Type type = nt.getType();

	if (l.getType().equals("i18n")) {
	    // FIXME: as a special case, allow an i18n layer to
	    // to override the 'des' property of a property, so
	    // that stuff can be translated
	    return;
	}

	// only core and layout layers can define properties
	if (! l.isCoreOrLayout()) {
	    throw new Exception("Only core and layout layers can define new properties.");
	}

	// make sure they aren't overriding a property from a lower layer
	if (ck.propertyType(name) != null) {
	    throw new Exception("Can't override an existing property '" + name + 
				"' at " + getFilePos());
	}

	if (! type.isSimple()) {
	    throw new Exception("Properties must be scalars, not arrays or hashes "+
				"at "+nt.getFilePos());
	}

        String basetype = type.baseType();
        if (! Type.isPrimitive(basetype) && ck.getClass(basetype) == null) {
            throw new Exception("Can't define a property of an unknown class "+
                                "at "+nt.getFilePos());
        }
	
	// all is well, so register this property with its type
	ck.addProperty(name, type);	
	
    } 


    public void asS2 (Indenter o)
    {
	o.tabwrite("property ");
	if (builtin) { o.write("builtin "); }
	nt.asS2(o);
	if (pairs.size() > 0) {
	    o.writeln(" {");
	    o.tabIn();
	    ListIterator li = pairs.listIterator(0);
	    while (li.hasNext()) {
		NodePropertyPair pp = (NodePropertyPair) li.next();
		pp.asS2(o);
	    }
	    o.tabOut();
	    o.writeln("}");
	} else {
	    o.writeln(";");
	}
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {
	o.tabwriteln("register_property("+
		     bp.getLayerIDString() + "," +
		     bp.quoteString(nt.getName()) + ",{");
	o.tabIn();
        o.tabwriteln("\"type\"=>" +
		     bp.quoteString(nt.getType().toString())+",");

	ListIterator li = pairs.listIterator();

	while (li.hasNext()) {
	    NodePropertyPair pp = (NodePropertyPair) li.next();
	    o.tabwriteln(bp.quoteString(pp.getKey()) + "=>" +
			 bp.quoteString(pp.getVal()) + ",");
	    
	}
	o.tabOut();
	o.writeln("});");
    }

};
