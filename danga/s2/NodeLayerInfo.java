package danga.s2;

import java.util.LinkedList;

public class NodeLayerInfo extends Node
{
    String key;
    String val;

    public String getKey () { return key; }
    public String getValue () { return val; }


    public static boolean canStart (Tokenizer toker) throws Exception
    {
	if (toker.peek().equals(TokenKeyword.LAYERINFO))
	    return true;
	return false;
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeLayerInfo n = new NodeLayerInfo();

	NodeText nkey, nval;

	n.requireToken(toker, TokenKeyword.LAYERINFO);
	n.addNode(nkey = (NodeText) NodeText.parse(toker));
	n.requireToken(toker, TokenPunct.ASSIGN);
	n.addNode(nval = (NodeText) NodeText.parse(toker));
	n.requireToken(toker, TokenPunct.SCOLON);

	n.key = nkey.getText();
	n.val = nval.getText();

	return n;
    }

    public void asS2 (Indenter o)
    {
	o.tabwrite("layerinfo ");
	o.write(Backend.quoteString(key));
	o.write(" = ");
	o.write(Backend.quoteString(val));
	o.writeln(";");
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {
	o.tabwriteln("set_layer_info("+
		     bp.getLayerIDString() + "," +
		     bp.quoteString(key) + "," +
		     bp.quoteString(val) + ");");
    }

    public void check (Layer l, Checker ck) throws Exception 
    {
	l.setLayerInfo(key, val);
    } 


};


