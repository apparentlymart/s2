package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;

public class BackendS2 extends Backend {

    private final static boolean MANY_QUOTES = false;
    
    public BackendS2 (Layer l) {
	layer = l;
    }
    
    public void output (Output o) 
    {
	Indenter io = new Indenter(o, 4);
	io.writeln("# auto-generated S2 code from input S2 code"); 
	LinkedList nodes = layer.getNodes();
	ListIterator li = nodes.listIterator();
	while (li.hasNext()) {
	    Node n = (Node) li.next();
	    n.asS2(io);
	}
    }

    public static void LParen (Indenter o) { if (MANY_QUOTES) o.write("("); }
    public static void RParen (Indenter o) { if (MANY_QUOTES) o.write(")"); }

};
