package danga.s2;

import java.util.Hashtable;
import java.util.ListIterator;
import java.util.LinkedList;
import java.util.Set;
import java.util.Collections;
import java.util.TreeSet;
import java.util.Iterator;

public class Checker
{
    // combined (all layers)
    private Hashtable classes;      // class name    -> NodeClass
    private Hashtable props;        // property name -> Type
    private Hashtable funcs;        // FuncID -> return type
    private Hashtable funcBuiltin;  // FuncID -> Boolean (is builtin)
    private LinkedList localblocks; // NodeStmtBlock scopes .. last is deepest (closest)
    private Type returnType;
    private String funcClass;       // current function class
    private Hashtable derclass;     // classname  -> LinkedList<classname>

    // per-layer
    private Hashtable funcDist;     // FuncID -> [ distance, NodeFunction ]
    private Hashtable funcIDs;      // NodeFunction -> Set<FuncID>
    private boolean hitFunction;    // true once a function has been declared/defined

    // per function
    private int funcNum = 0;
    private Hashtable funcNums;     // FuncID -> Integer(funcnum)
    
    public Checker ()
    {
	classes = new Hashtable();
	props = new Hashtable();
	funcs = new Hashtable();
	funcBuiltin = new Hashtable();
	derclass = new Hashtable();
	localblocks = new LinkedList();
    }
    
    // class functions
    public void addClass (String name, NodeClass nc) {
	classes.put(name, nc);
	
	// make sure that the list of classes that derive from this
	// one exists.
	if (derclass.get(name) == null) {
	    derclass.put(name, new LinkedList());
	}

	// and if this class derives from another, add ourselves
	// to that list.
	String parent = nc.getParentName();
	if (parent != null) {
	    LinkedList l = (LinkedList) derclass.get(parent);
	    l.add(name);
	}
    }
    public NodeClass getClass (String name) {
	return (NodeClass) classes.get(name);
    }

    public boolean isValidType (Type t) {
        if (t == null) return false;
        if (t.isPrimitive()) return true;
        if (getClass(t.baseType()) != null) return true;
        return false;
    }

    // property functions
    public void addProperty (String name, Type t) {
	props.put(name, t);
    }
    public Type propertyType (String name) {
	return (Type) props.get(name);
    }

    // return type of null means no return type.
    public void setReturnType (Type t) {
	returnType = t;
    }
    public Type getReturnType () {
	return returnType;
    }

    // function functions
    public void addFunction (String funcid, Type t, boolean builtin) 
	throws Exception 
    {
	// make sure function doesn't mask a lower one with a different type
	Type existing = functionType(funcid);
	if (existing != null && ! existing.equals(t)) {
	    throw new Exception("Can't override function '" + funcid + "' with new "+
				"return type.");
	}
	
	funcs.put(funcid, t);
	funcBuiltin.put(funcid, new Boolean(builtin));
    }
    public Type functionType (String funcid) {
	return (Type) funcs.get(funcid);
    }
    public boolean isFuncBuiltin (String funcid) {
	Boolean b = (Boolean)funcBuiltin.get(funcid);
	return b == null ? false : b.booleanValue();
    }

    // setting/getting the current function class we're in
    public void setCurrentFunctionClass (String f) {
	funcClass = f;
    }
    public String getCurrentFunctionClass () {
	return funcClass;
    }

    // variable lookup
    public void pushLocalBlock (NodeStmtBlock nb) {
	localblocks.addLast(nb);
    }
    public void popLocalBlock () {
	localblocks.removeLast();
    }
    public NodeStmtBlock getLocalScope () {
	if (localblocks.size() == 0) 
	    return null;
	return (NodeStmtBlock) localblocks.getLast();
    }
    
    public Type localType (String local) 
    {
	if (localblocks.size() == 0) 
	    return null;

	ListIterator li = localblocks.listIterator(localblocks.size());
	while (li.hasPrevious()) {
	    NodeStmtBlock nb = (NodeStmtBlock) li.previous();
	    Type t = nb.getLocalVar(local);
	    if (t != null)
		return t;
	}
	return null;
    }
    public Type memberType (String clas, String member) 
    {
	NodeClass nc = getClass(clas);
	if (nc == null) return null;
	return nc.getMemberType(member);
    }

    public void setHitFunction (boolean b) {
	hitFunction = b;
    }
    public boolean getHitFunction () {
	return hitFunction;
    }

    public boolean hasDerClasses (String clas) {
	LinkedList l = (LinkedList) derclass.get(clas);
	return l.size() > 0;
    }

    public ListIterator getDerClassesIter (String clas) {
	LinkedList l = (LinkedList) derclass.get(clas);
	return l.listIterator();
    }

    public void setFuncDistance (String funcID, DerItem df) 
    {
	//System.err.println("setFuncDistance(\""+funcID+"\", "+df+")");

	DerItem existing = (DerItem) funcDist.get(funcID);
	if (existing == null || df.dist < existing.dist) {
	    funcDist.put(funcID, df);

	    ///// keep the funcIDs hashes -> FuncID set up-to-date
	    // removing the existing funcID from the old set first
	    if (existing != null) {
		Set oldset = (Set) funcIDs.get(existing.nf);
		oldset.remove(funcID);
	    }

	    // first, make sure the set exists
	    Set idset = (Set) funcIDs.get(df.nf);
	    if (idset == null) {
		idset = Collections.synchronizedSortedSet(new TreeSet());
		funcIDs.put(df.nf, idset);
	    }

	    // now, insert this funcID for this function.
	    idset.add(funcID);
	}
    }

    public Iterator getFuncIDsIter (NodeFunction nf)
    {
	Set s = (Set) funcIDs.get(nf);
	if (s == null) {
	    System.err.println("WARN: no funcids for nf="+nf);
	    return null;
	}
	return s.iterator();
    }

    // per function
    public void resetFunctionNums () {
	funcNum = 0;
	funcNums = new Hashtable();
    }
    public int functionNum (String funcID) {
	Integer num = (Integer) funcNums.get(funcID);
	if (num == null) {
	    num = new Integer(++funcNum);
	    funcNums.put(funcID, num);
	}
	return num.intValue();
    }
    public Hashtable getFuncNums () {
	return funcNums;
    }

    // check if type 't' is a subclass of 'w'
    public boolean typeIsa (Type t, Type w) 
    {
	if (! Type.sameMods(t, w))
	    return false;
	
	String is = t.baseType();
	String parent = w.baseType();
	while (is != null) {
	    if (is.equals(parent))
		return true;

	    NodeClass nc = getClass(is);
	    is = nc != null ? nc.getParentName() : null;
	};
	return false ;
    }

    // check to see if a class or parents has a
    // "toString()" method
    public boolean classHasToString (String clas) {
	Type et = functionType(clas+"::toString()");
	if (et != null && et.equals(Type.STRING))
	    return true;
	return false;
    }

    // check to see if a class or parents has an
    // "as_string" string member
    public boolean classHasAsString (String clas) {
	Type et = memberType(clas, "as_string");
	if (et != null && et.equals(Type.STRING))
	    return true;
	return false;
    }

    // ------

    public void checkLayer (Layer lay) throws Exception
    {
	// initialize layer-specific data structures
	funcDist = new Hashtable();
	funcIDs = new Hashtable();
	hitFunction = false;

	// check to see that they declared the layer type, and that
	// it isn't bogus.
	{
	    // what the S2 source says the layer is
	    String dtype = lay.getDeclaredType();
	    if (dtype == null)
		throw new Exception("Layer type not declared.");

	    // what type s2compile thinks it is
	    String type = lay.getType();

            if (! dtype.equals(type)) {
                throw new Exception("Layer is declared " + dtype +
                                    " but expecting a "+type+" layer.");
            }

	    // now that we've validated their type is okay
	    lay.setType(dtype);
	}

	LinkedList nodes = lay.getNodes();
	ListIterator li = nodes.listIterator();
	while (li.hasNext()) {
	    Node n = (Node) li.next();
	    n.check(lay, this);
	}

        if (lay.getType().equals("core")) {
            String mv = lay.getLayerInfo("majorversion");
            if (mv == null) {
                throw new Exception("Core layers must declare 'majorversion' layerinfo.");
            }
        }
    }


    // static stuff

    // returns the signature of a function and its arguments, in the form
    // of:   Classname::funcName(String,UserPage,int)
    public static String functionID (String clas, String func, Object o)
    {
	StringBuffer sb = new StringBuffer(70);

	if (clas != null) {
	    sb.append(clas); sb.append("::");
	}
	sb.append(func);
	sb.append("(");

	// where Object can be a NodeFormals or FIXME: other stuff
	if (o == null) {
	    // do nothing.
	} else if (o instanceof NodeFormals) {
	    NodeFormals nf = (NodeFormals) o;
	    sb.append(nf.typeList());
	} else if (o instanceof String) {
	    String s = (String) o;
	    sb.append(s);
	} else {
	    sb.append("[-----]");
	}

	sb.append(")");
	return sb.toString();	
    }
}
