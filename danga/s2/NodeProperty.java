package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;

public class NodeProperty extends Node
{
    NodeNamedType nt;
    LinkedList pairs;
    boolean builtin = false, use = false, hide = false;
    String uhName;    // if use or hide, then this is property to use/hide

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

	n.setStart(n.requireToken(toker, TokenKeyword.PROPERTY));

	if (toker.peek().equals(TokenKeyword.BUILTIN)) {
	    n.builtin = true;
	    n.eatToken(toker);
	}

        // parse the use/hide case
        if (toker.peek() instanceof TokenIdent) {
            String ident = ((TokenIdent) toker.peek()).getIdent();
            if (ident.equals("use") || ident.equals("hide")) {
                if (ident.equals("use")) n.use = true;
                if (ident.equals("hide")) n.hide = true;
                n.eatToken(toker);
                
                Token t = toker.peek();
                if (! (t instanceof TokenIdent)) {
                    throw new Exception("Expecting identifer after "+ident+" at "+t.getFilePos());
                }
                n.uhName = ((TokenIdent) toker.peek()).getIdent();
                n.eatToken(toker);
                n.requireToken(toker, TokenPunct.SCOLON);
                return n;
            }
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
        if (use) {
            if (! l.getType().equals("layout")) {
                throw new Exception("Can't declare property usage in non-layout layer at"
                                    + getFilePos());
            }
            if (ck.propertyType(uhName) == null) {
                throw new Exception("Can't declare usage of non-existent property at"
                                    + getFilePos());
            }
            return;
        }

        if (hide) {
            if (ck.propertyType(uhName) == null) {
                throw new Exception("Can't hide non-existent property at"
                                    + getFilePos());
            }
            return;
        }

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
        Type existing = ck.propertyType(name);
        if (existing != null && ! type.equals(existing)) {
	    throw new Exception("Can't override property '" + name + 
				"' at " + getFilePos() + " of type "+existing+
                                " with new type "+type+".");
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
        if (use || hide) {
            if (use) o.write("use ");
            if (hide) o.write("hide ");
            o.write(uhName);
            o.writeln(";");
            return;               
        }
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
        if (use) {
            o.tabwriteln("register_property_use("+
                         bp.getLayerIDString() + "," +
                         bp.quoteString(uhName) + ");");
            return;               
        }

        if (hide) {
            o.tabwriteln("register_property_hide("+
                         bp.getLayerIDString() + "," +
                         bp.quoteString(uhName) + ");");
            return;               
        }

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
