package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;

public class Type implements Cloneable
{
    public final static Type VOID   = new Type("void");
    public final static Type STRING = new Type("string");
    public final static Type INT    = new Type("int");
    public final static Type BOOL   = new Type("bool");

    protected LinkedList typeMods; // stores "[]" and "{}" information
    protected String baseType;

    protected boolean readOnly = false;

    public Object clone () {
	Type nt = new Type (baseType);

	// GCJBUG: this doesn't work in gcj
	//	nt.typeMods = (LinkedList) typeMods.clone();

	// GCJBUG: this works:
	nt.typeMods = new LinkedList();
	for (ListIterator li = typeMods.listIterator(); li.hasNext(); ) {
	    nt.typeMods.add(li.next());
	}
        nt.readOnly = readOnly;

	return nt;
    }

    public Type (String baseType) {
	this.baseType = baseType;
	typeMods = new LinkedList();
    }

    // return true if the type is an INT or BOOL (something
    // that can be interpretted in a boolean context)
    public boolean isBoolable () 
    {
	return (equals(BOOL) || equals(INT));
    }

    // return a vector of all the sub-types this could be:
    // if this is a A[][], would return A[][], B[][], C[][]
    public ListIterator subTypesIter (Checker ck)
    {
	LinkedList l = new LinkedList();
	NodeClass nc = ck.getClass(baseType);
	if (nc == null) {
	    // no sub-classes.  just return our type.
	    l.add(this);
	    return l.listIterator();
	}
	ListIterator di = nc.getDerClasses().listIterator();
	while (di.hasNext()) {
	    // add a copy of this type to the list, but with
	    // the derivative class type.
	    DerItem der = (DerItem) di.next();
	    String c = der.nc.getName();
	    Type newt = (Type) clone();
	    newt.baseType = c;
	    l.add(newt);
	}
	return l.listIterator();
    }
    
    public boolean equals (Object o) {
	if (! (o instanceof Type)) return false;
	Type ot = (Type) o;
	if (ot.baseType.equals(baseType) &&
	    ot.typeMods.equals(typeMods))
	    return true;
	return false;
    }

    public static boolean sameMods (Type a, Type b)
    {
	if (a.typeMods.equals(b.typeMods))
	    return true;
	return false;
    }

    public void makeArrayOf () {
	typeMods.addLast("[]");
    }

    public void makeHashOf () {
	typeMods.addLast("{}");
    }

    public void removeMod () {
	try {
	    typeMods.removeLast();
	} catch (Exception e) { }
    }

    // return true if it's not a hashof or arrayof
    public boolean isSimple () {
	return (typeMods.size() == 0);
    }
    
    private boolean isThing (String s) {
	try {
	    Object o = typeMods.removeLast();
	    typeMods.addLast(o);
	    return o.equals(s);
	} catch (Exception e) {
	    return false;
	}	
    }

    public boolean isHashOf () { return isThing("{}"); }
    public boolean isArrayOf () { return isThing("[]"); }

    public String baseType () 
    {
	return baseType;
    }

    public String toString ()
    {
	StringBuffer sb = new StringBuffer(baseType);
	ListIterator li = typeMods.listIterator(0);
	while (li.hasNext()) {
	    String s = (String) li.next();
	    sb.append(s);
	}
	return sb.toString();
    }

    public static boolean isPrimitive (String bt)
    {
	Type t = new Type(bt);
	return (t.equals(STRING) ||
		t.equals(INT) ||
		t.equals(BOOL));
    }

    public boolean isPrimitive () {
        return (this.equals(STRING) ||
                this.equals(INT) ||
                this.equals(BOOL));
            
    }

    public boolean isReadOnly () { return readOnly; }
    public void setReadOnly (boolean b) { readOnly = b; }

}
