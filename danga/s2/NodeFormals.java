package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;
import java.util.Hashtable;

public class NodeFormals extends Node
{
    public LinkedList listFormals = new LinkedList(); // NodeNamedType

    public NodeFormals () { }
    public NodeFormals (LinkedList formals) {
	listFormals = formals;
    }
    
    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeFormals n = new NodeFormals();
	int count = 0;

	n.requireToken(toker, TokenPunct.LPAREN);
	while (toker.peek() != null && ! toker.peek().equals(TokenPunct.RPAREN)) {
	    if (count > 0) {
		n.requireToken(toker, TokenPunct.COMMA);
	    }
	    n.skipWhite(toker);

	    NodeNamedType nf = (NodeNamedType) NodeNamedType.parse(toker);
	    n.listFormals.add(nf);
	    n.tokenlist.add(nf);

	    n.skipWhite(toker);
	    count++;
	}
	n.requireToken(toker, TokenPunct.RPAREN);

	return n;
    }

    public void check (Layer l, Checker ck) throws Exception
    {
	Hashtable h = new Hashtable();
	ListIterator li = listFormals.listIterator();
	while (li.hasNext()) {
	    NodeNamedType nt = (NodeNamedType) li.next();
	    String name = nt.getName();
	    if (h.get(name) != null) {
		throw new Exception("Duplicate argument named '" + name + "' at "+
				    nt.getFilePos());
	    } else {
		h.put(name, name);
	    }
	}
    }

    public void asS2 (Indenter o) {
	if (listFormals.size() == 0) return; // no empty parens necessary in S2
	o.write(toString());
    }

    public String toString () {
        StringBuffer sb = new StringBuffer("(");
	ListIterator li = listFormals.listIterator();
	boolean first = true;
	while (li.hasNext()) {
	    NodeNamedType nf = (NodeNamedType) li.next();
	    if (! first) {
		sb.append(", ");
	    }
	    first = false;

	    sb.append(nf.toString());
	}

        sb.append(")");
        return sb.toString();
    }

    // returns a ListIterator returning variations of this NodeFormal
    // object using derived classes as well.
    public static ListIterator variationIterator (NodeFormals nf, Checker ck)
    {
	LinkedList l = new LinkedList();
	if (nf == null) {
	    l.add(new NodeFormals(new LinkedList()));
	} else {
	    nf.getVariations(ck, l, new LinkedList(), 0);
	}
	return l.listIterator();
    }

    private void getVariations (Checker ck, 
				LinkedList vars, 
				LinkedList temp,
				int col)
    {
	if (col == listFormals.size()) {
	    vars.add(new NodeFormals(temp));
	    return;
	}
	
	NodeNamedType nt = (NodeNamedType) listFormals.get(col);
	Type t = nt.getType();

	for (ListIterator li = t.subTypesIter(ck); li.hasNext(); ) {
	    t = (Type) li.next();
	    LinkedList newtemp = (LinkedList) temp.clone();
	    newtemp.add(new NodeNamedType(nt.getName(), t));
	    getVariations(ck, vars, newtemp, col+1);
	}
    }

    public String typeList () 
    {
	StringBuffer sb = new StringBuffer(50);
	if (listFormals.size() == 0) return sb.toString();

	ListIterator li = listFormals.listIterator();
	boolean first = true;
	while (li.hasNext()) {
	    NodeNamedType nt = (NodeNamedType) li.next();
	    if (! first) sb.append(",");
	    first = false;

	    sb.append(nt.getType().toString());
	}

	return sb.toString();
    }

    // adds all these variables to the stmtblock's symbol table
    public void populateScope (NodeStmtBlock nb)
    {
	if (listFormals.size() == 0) return;
	
	ListIterator li = listFormals.listIterator();
	while (li.hasNext()) {
	    NodeNamedType nt = (NodeNamedType) li.next();
	    nb.addLocalVar(nt.getName(), nt.getType());
	}
     }

    public ListIterator iterator() {
	return listFormals.listIterator();
    }
};
