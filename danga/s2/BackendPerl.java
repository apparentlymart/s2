package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;

public class BackendPerl extends Backend {
    
    int layerID;

    public BackendPerl (Layer l, int layerID) {
	layer = l;
	this.layerID = layerID;
    }

    public int getLayerID () { return layerID; }
    public String getLayerIDString () { 
	return (new Integer(layerID)).toString(); 
    }
    
    public void output (Output o) {
	Indenter io = new Indenter(o, 4);
	io.writeln("#!/usr/bin/perl");
	io.writeln("# auto-generated Perl code from input S2 code"); 
	io.writeln("package S2;");
	io.writeln("use strict;");
	io.writeln("use constant VTABLE => 0;");
	io.writeln("use constant STATIC => 1;");
	io.writeln("use constant PROPS => 2;");
	io.writeln("register_layer("+layerID+");");
	LinkedList nodes = layer.getNodes();
	ListIterator li = nodes.listIterator();
	while (li.hasNext()) {
	    Node n = (Node) li.next();
	    n.asPerl(this, io);
	}
	io.writeln("1;");
	io.writeln("# end.");
    }

    public static String quoteString (String s)
    {
	int len = s.length();
	StringBuffer sb = new StringBuffer(len + 20);
	sb.append("\"");
	sb.append(quoteStringInner(s));
	sb.append("\"");
	return sb.toString();
    }

    public static String quoteStringInner (String s)
    {
	int len = s.length();
	StringBuffer sb = new StringBuffer(len + 20);
	for (int i=0; i<len; i++) {
	    char c = s.charAt(i);
	    if (c=='\n') {
		sb.append("\\n");
	    } else {
		if (c=='\\' || c=='$' || c=='"' || c=='@') 
		    sb.append('\\');
		sb.append(c);
	    }
	}
	return sb.toString();
    }

};
