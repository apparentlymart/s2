package danga.s2;

public class NodeNamedType extends Node
{
    public Type type;
    public NodeType typenode;
    public String name;

    public Type getType () {
	return type;
    }
    public String getName () {
	return name;
    }

    public NodeNamedType () {
    }

    public NodeNamedType (String name, Type type) {
	this.name = name;
	this.type = type;
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeNamedType n = new NodeNamedType();

	n.typenode = (NodeType) NodeType.parse(toker);
	n.type = n.typenode.getType();

	n.addNode(n.typenode);
	n.name = n.getIdent(toker).getIdent();

	return n;
    }

    public void asS2 (Indenter o) 
    {
	typenode.asS2(o);
	o.write(" " + name);
    }

    public String toString ()  // was asString
    {
	return type.toString() + " " + name;
    }

};
