package danga.s2;

public class NodePropertyPair extends Node
{
    NodeText key;
    NodeText val;

    public String getKey () { return key.getText(); }
    public String getVal () { return val.getText(); }

    public static boolean canStart (Tokenizer toker) throws Exception
    {
	if (NodeText.canStart(toker))
	    return true;
	return false;
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	NodePropertyPair n = new NodePropertyPair();
	
	n.addNode(n.key = (NodeText) NodeText.parse(toker));
	n.requireToken(toker, TokenPunct.ASSIGN);
	n.addNode(n.val = (NodeText) NodeText.parse(toker));
	n.requireToken(toker, TokenPunct.SCOLON);
	
	return n;
    }

    public void asS2 (Indenter o) 
    {
	o.doTab();
	key.asS2(o);
	o.write(" = ");
	val.asS2(o);
	o.writeln(";");
    }


};
