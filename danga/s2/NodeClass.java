package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;
import java.util.Hashtable;

public class NodeClass extends Node
{
    TokenIdent name;
    TokenIdent parentName;
    
    String docstring;

    LinkedList vars = new LinkedList();      // NodeNamedType
    Hashtable varType = new Hashtable();     // token String -> Type
	
    LinkedList functions = new LinkedList(); // NodeFunction
    Hashtable funcType = new Hashtable();    // funcID String -> Type

    NodeClass  parentClass;  // Not set until check() is run

    // this is kinda ugly, keeping a reference to the checker for use
    // later, but there's only ever one checker, so it's okay.
    Checker ck;

    public String getParentName() {
	if (parentName == null) return null;
	return parentName.getIdent();
    }

    public static boolean canStart (Tokenizer toker) throws Exception {
	if (toker.peek().equals(TokenKeyword.CLASS)) 
	    return true;
	return false;
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeClass n = new NodeClass();

	n.setStart(n.requireToken(toker, TokenKeyword.CLASS));

	n.name = n.getIdent(toker);

	if (toker.peek().equals(TokenKeyword.EXTENDS)) {
	    n.eatToken(toker);
	    n.parentName = n.getIdent(toker);
	}

        // docstring
        if (toker.peek() instanceof TokenStringLiteral) {
            TokenStringLiteral t = (TokenStringLiteral) n.eatToken(toker);
            n.docstring = t.getString();
        }

	n.requireToken(toker, TokenPunct.LBRACE);

	while (toker.peek() != null && toker.peek() instanceof TokenKeyword) {
	    if (toker.peek().equals(TokenKeyword.VAR)) {
		NodeClassVarDecl ncvd = (NodeClassVarDecl) NodeClassVarDecl.parse(toker);
		n.vars.add(ncvd);
		n.addNode(ncvd);
	    } else if (toker.peek().equals(TokenKeyword.FUNCTION)) {
		NodeFunction nm = (NodeFunction) NodeFunction.parse(toker, true);
		n.functions.add(nm);
		n.addNode(nm);
	    }
	}

	n.requireToken(toker, TokenPunct.RBRACE);
	return n;
    }

    public String getName () {
	return name.getIdent();
    }
    public Type getFunctionType (String funcID) {
	Type t = (Type) funcType.get(funcID);
	if (t != null) return t;
	if (parentClass != null)
	    return parentClass.getFunctionType(funcID);
	return null;
    }
    public NodeClass getFunctionDeclClass (String funcID) {
	Type t = (Type) funcType.get(funcID);
	if (t != null) return this;
	if (parentClass != null)
	    return parentClass.getFunctionDeclClass(funcID);
	return null;
    }

    public Type getMemberType (String mem) {
	Type t = (Type) varType.get(mem);
	if (t != null) return t;
	if (parentClass != null) {
	    return parentClass.getMemberType(mem);
	}
	return null;
    }

    // returns LinkedList<DerClass> from the current class down to
    // all children classes.
    public LinkedList getDerClasses () {
	return getDerClasses(null, 0);
    }

    private LinkedList getDerClasses (LinkedList l, int depth) {
	if (l == null) l = new LinkedList();
	l.add(new DerItem(this, depth));
	ListIterator li = ck.getDerClassesIter(getName());
	while (li.hasNext()) {
	    String cname = (String) li.next();
	    NodeClass c = ck.getClass(cname);
	    c.getDerClasses(l, depth+1);
	}
	return l;
    }

    // returns the class/parent-class the named member variable was
    // defined in.
    public NodeClass getMemberDeclClass (String mem) {
	Type t = (Type) varType.get(mem);
	if (t != null) return this;
	if (parentClass != null) {
	    return parentClass.getMemberDeclClass(mem);
	}
	return null;
    }

    public void check (Layer l, Checker ck) throws Exception 
    {
	ListIterator li;
	this.ck = ck;

	// can't declare classes inside of a layer if functions
	// have already been declared or defined.
	if (ck.getHitFunction()) {
	    throw new Exception("Can't declare a class inside a layer "+
				"file after functions have been defined at "+
				getFilePos());
	}

	// if this is an extended class, make sure parent class exists
	parentClass = null;
	if (parentName != null) {
	    String pname = parentName.getIdent();
	    parentClass = ck.getClass(pname);
	    if (parentClass == null) {
		throw new Exception("Can't extend non-existent class '"+
				    pname+"' at "+getFilePos());
	    }
	}

	// make sure the class isn't already defined.
	String cname = name.getIdent();
	if (ck.getClass(cname) != null) {
	    throw new Exception("Can't redeclare class '"+cname+"' at "+
				getFilePos());
	}

	// register all var and function declarations in hash & check for both
	// duplicates and masking of parent class's declarations

	// register self.  this needs to be done before checking member
        // variables so we can have members of our own type.
	ck.addClass(cname, this);

	// member vars
	for (li = vars.listIterator(); li.hasNext(); )  {
	    NodeClassVarDecl nnt = (NodeClassVarDecl) li.next();
            boolean readonly = nnt.isReadOnly();
	    String vn = nnt.getName();
	    Type vt = nnt.getType();
	    Type et = getMemberType(vn);
	    if (et != null) {
		NodeClass oc = getMemberDeclClass(vn);
		throw new Exception("Can't declare the variable '"+vn+"' "+
				    "as '"+vt+"' in class '"+cname+"' at "+
				    nnt.getFilePos()+" because it's "+
				    "already defined in class '"+oc.getName()+"' as "+
				    "type '"+et+"'.");
	    }

            // check to see if type exists
            if (ck.isValidType(vt) != true) {
                throw new Exception("Can't declare member variable '"+vn+"' "+
                                    "as unknown type '"+vt+"' in class '"+cname+"' at "+
                                    nnt.getFilePos());
            }

            vt.setReadOnly(readonly);
	    varType.put(vn, vt);  // register member variable
	}

	// all parent class functions need to be inherited:
	registerFunctions(ck, cname);
    }

    private void registerFunctions (Checker ck, String clas) throws Exception
    {
	// register parent's functions first.
	if (parentClass != null)
	    parentClass.registerFunctions(ck, clas);

	// now do our own
	for (ListIterator li = functions.listIterator(); li.hasNext(); )  {
	    NodeFunction nf = (NodeFunction) li.next();
	    Type rettype = nf.getReturnType();
	    nf.registerFunction(ck, clas);
	}
    }

    public void asS2 (Indenter o) 
    {
	ListIterator li;

	o.tabwrite("class " + name.getIdent() + " ");
	if (parentName != null) {
	    o.write("extends " + parentName.getIdent() + " ");
	}
	o.writeln("{");
	o.tabIn();

	// vars
	for (li = vars.listIterator(0); li.hasNext(); )  {
	    NodeClassVarDecl vd = (NodeClassVarDecl) li.next();
	    vd.asS2(o);
	}

	// functions
	for (li = functions.listIterator(0); li.hasNext(); )  {
	    NodeFunction nf = (NodeFunction) li.next();
	    nf.asS2(o);
	}
	
	o.tabOut();
	o.writeln("}");
    }

    public void asPerl (BackendPerl bp, Indenter o) {
	o.tabwriteln("register_class(" + bp.getLayerIDString() +
                     ", " + bp.quoteString(name.getIdent()) + ", {");
        o.tabIn();
        if (parentName != null) {
            o.tabwriteln("'parent' => " + bp.quoteString(parentName.getIdent()) + ",");
        }
        if (docstring != null) {
            o.tabwriteln("'docstring' => " + bp.quoteString(docstring) + ",");
        }

        // vars
        o.tabwriteln("'vars' => {");
        o.tabIn();
	for (ListIterator li = vars.listIterator(); li.hasNext(); )  {
	    NodeClassVarDecl nnt = (NodeClassVarDecl) li.next();
	    String vn = nnt.getName();
	    Type vt = nnt.getType();
	    Type et = getMemberType(vn);
            o.tabwrite(bp.quoteString(vn) + " => { 'type' => " + bp.quoteString(vt.toString()));
            if (vt.isReadOnly()) {
                o.write(", 'readonly' => 1");
            }
            if (nnt.getDocString() != null) {
                o.write(", 'docstring' => " + bp.quoteString(nnt.getDocString()));
            }
            o.writeln(" },");
        }        
        o.tabOut();
        o.tabwriteln("},");

        // methods
        o.tabwriteln("'funcs' => {");
        o.tabIn();
	for (ListIterator li = functions.listIterator(); li.hasNext(); )  {
	    NodeFunction nf = (NodeFunction) li.next();
	    String name = nf.getName();
            NodeFormals nfo = nf.getFormals();
	    Type rt = nf.getReturnType();
            o.tabwrite(bp.quoteString(name + ((nfo != null) ? nfo.toString() : "()"))
                                      + " => { 'returntype' => " 
                                      + bp.quoteString(rt.toString()));
            if (nf.getDocString() != null) {
                o.write(", 'docstring' => " + bp.quoteString(nf.getDocString()));
            }
            o.writeln(" },");
        }        
        o.tabOut();
        o.tabwriteln("},");
        

        o.tabOut();
        o.tabwriteln("});");
        
    }

};
