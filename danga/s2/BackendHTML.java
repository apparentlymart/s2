package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;

public class BackendHTML extends Backend {

    public final static boolean addBreaks    = false;
    public final static String CommentColor  = new String("#008000");
    public final static String IdentColor    = new String("#000000");
    public final static String KeywordColor  = new String("#0000FF");
    public final static String StringColor   = new String("#008080");
    public final static String PunctColor    = new String("#000000");
    public final static String BracketColor  = new String("#800080");
    public final static String TypeColor     = new String("#000080");
    public final static String VarColor      = new String("#000000");
    public final static String IntegerColor  = new String("#000000");

    public BackendHTML (Layer l) {
	layer = l;
    }

    public void output (Output o) {
	String layername = (s2compile.topLayerName == null ?
	                    "untitled layer" :
	                    s2compile.topLayerName);

        o.write("<html><head><title>Source for "+layername+"</title>\n");
        o.write("<style type=\"text/css\">\n");
        o.write("body { background: #ffffff none; color: #000000; }\n");
        o.write(".c { background: #ffffff none; color: "+CommentColor+"; }\n");
        o.write(".i { background: #ffffff none; color: "+IdentColor+"; }\n");
        o.write(".k { background: #ffffff none; color: "+KeywordColor+"; }\n");
        o.write(".s { background: #ffffff none; color: "+StringColor+"; }\n");
        o.write(".p { background: #ffffff none; color: "+PunctColor+"; }\n");
        o.write(".b { background: #ffffff none; color: "+BracketColor+"; }\n");
        o.write(".t { background: #ffffff none; color: "+TypeColor+"; }\n");
        o.write(".v { background: #ffffff none; color: "+VarColor+"; }\n");
        o.write(".n { background: #ffffff none; color: "+IntegerColor+"; }\n");
	o.write("</style></head><body><pre>");
	LinkedList nodes = layer.getNodes();
	ListIterator li = nodes.listIterator();
	while (li.hasNext()) {
	    Node n = (Node) li.next();
	    n.asHTML(o);
	}
	o.write("</pre></body></html>"); o.newline();
    }

    public static String quoteHTML (String s)
    {
	int len = s.length();
	StringBuffer sb = new StringBuffer(len + len / 10);
	for (int i=0; i<len; i++) {
	    char c = s.charAt(i);
	    if (c=='<')
		sb.append("&lt;");
	    else if (c=='>')
		sb.append("&gt;");
	    else if (c=='&')
		sb.append("&amp;");
	    else
		sb.append(c);
	}
	return sb.toString();
    }

};
