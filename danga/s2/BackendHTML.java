package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;

public class BackendHTML extends Backend {
    
    public final static boolean addBreaks    = false;
    public final static String CommentColor  = new String("#c00000");
    public final static String IdentColor    = new String("#000000");
    public final static String KeywordColor  = new String("#9020c0");
    public final static String StringColor   = new String("#779977");
    public final static String PunctColor    = new String("#000000");
    public final static String TypeColor     = new String("#0000dd");
    public final static String VarColor      = new String("#ff9b0f");
    public final static String IntegerColor  = new String("#00b578");

    public BackendHTML (Layer l) {
	layer = l;
    }

    public void output (Output o) {
	o.write("<pre>"); 
	LinkedList nodes = layer.getNodes();
	ListIterator li = nodes.listIterator();
	while (li.hasNext()) {
	    Node n = (Node) li.next();
	    n.asHTML(o);
	}
	o.write("</pre>"); o.newline();
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
