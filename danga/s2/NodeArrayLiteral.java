package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;

// [ <NodeExpr>? (, <NodeExpr>)* ,? ]
// { (<NodeExpr> => <NodeExpr> ,)* }

public class NodeArrayLiteral extends NodeExpr
{
    boolean isHash = false;
    boolean isArray = false;

    LinkedList keys = new LinkedList();
    LinkedList vals = new LinkedList();
    
    public static boolean canStart (Tokenizer toker) throws Exception
    {
	return (toker.peek().equals(TokenPunct.LBRACK) ||
                toker.peek().equals(TokenPunct.LBRACE));
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeArrayLiteral nal = new NodeArrayLiteral();

        Token t = toker.peek();	
        if (t.equals(TokenPunct.LBRACK)) {
            nal.isArray = true;
            nal.setStart(nal.requireToken(toker, TokenPunct.LBRACK));
        } else {
            nal.isHash = true;
            nal.setStart(nal.requireToken(toker, TokenPunct.LBRACE));
        }
        
        boolean need_comma = false;
        while (true) {
            t = toker.peek();

            // find the ends
            if (nal.isArray && t.equals(TokenPunct.RBRACK)) {
                nal.requireToken(toker, TokenPunct.RBRACK);
                return nal;
            }
            if (nal.isHash && t.equals(TokenPunct.RBRACE)) {
                nal.requireToken(toker, TokenPunct.RBRACE);
                return nal;
            }

            if (need_comma) {
                throw new Exception("Expecting comma at "+toker.getPos());
            }

            if (nal.isArray) {
                NodeExpr ne = (NodeExpr) NodeExpr.parse(toker);
                nal.vals.add(ne);
                nal.addNode(ne);
            }
            if (nal.isHash) {
                NodeExpr ne = (NodeExpr) NodeExpr.parse(toker);
                nal.keys.add(ne);

                nal.requireToken(toker, TokenPunct.HASSOC);

                ne = (NodeExpr) NodeExpr.parse(toker);
                nal.vals.add(ne);
                nal.addNode(ne);
            }

            need_comma = true;
            if (toker.peek().equals(TokenPunct.COMMA)) {
                nal.requireToken(toker, TokenPunct.COMMA);
                need_comma = false;
            }
        }
    }

    public void asS2 (Indenter o)
    {
	o.writeln(isArray ? "[" : "{");
        o.tabIn();
        ListIterator liv = vals.listIterator();
        ListIterator lik = keys.listIterator();
        Node n;
        while (liv.hasNext()) {
            o.tabwrite("");
            if (isHash) {
                n = (Node) lik.next();
                n.asS2(o);
                o.write(" => ");
            }
            n = (Node) liv.next();
            n.asS2(o);
            o.writeln(",");
        }
        o.tabOut();
	o.tabwrite(isArray ? "]" : "}");
    }

    public Type getType (Checker ck, Type wanted) throws Exception
    {
        // in case of empty array [] or hash {}, the type is what they wanted,
        // if they wanted something, otherwise void[] or void{}
        Type t;
	if (vals.size() == 0) {
            if (wanted != null) return wanted;
            t = new Type("void");
            if (isArray) t.makeArrayOf();
            if (isHash) t.makeHashOf();
            return t;
        }

        ListIterator liv = vals.listIterator();
        ListIterator lik = keys.listIterator();
        
        t = (Type) ((Node) liv.next()).getType(ck).clone();
        while (liv.hasNext()) {
            Node n = (Node) liv.next();
            Type next = n.getType(ck);
            if (! t.equals(next)) {
                throw new Exception("Array literal with inconsistent types: "+
                                    "starts with "+t+", but then has "+next+" at "+
                                    n.getFilePos());
            }
        }

        if (isArray) t.makeArrayOf();
        if (isHash) t.makeHashOf();
        return t;
    }    

    public Type getType (Checker ck) throws Exception
    {
	return getType(ck, null);
    }    

    public void asPerl (BackendPerl bp, Indenter o)
    {
	o.writeln(isArray ? "[" : "{");
        o.tabIn();
        ListIterator liv = vals.listIterator();
        ListIterator lik = keys.listIterator();
        Node n;
        while (liv.hasNext()) {
            o.tabwrite("");
            if (isHash) {
                n = (Node) lik.next();
                n.asPerl(bp, o);
                o.write(" => ");
            }
            n = (Node) liv.next();
            n.asPerl(bp, o);
            o.writeln(",");
        }
        o.tabOut();
	o.tabwrite(isArray ? "]" : "}");

    }

};
