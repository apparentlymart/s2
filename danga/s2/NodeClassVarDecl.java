package danga.s2;

public class NodeClassVarDecl extends Node
{
    public Type type;
    public NodeType typenode;
    public String name;
    public String docstring;

    public Type getType () {
	return type;
    }
    public String getName () {
	return name;
    }

    public String getDocString () {
        return docstring;
    }

    public NodeClassVarDecl () {
    }

    public NodeClassVarDecl (String name, Type type) {
	this.name = name;
	this.type = type;
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeClassVarDecl n = new NodeClassVarDecl();

        n.setStart(n.requireToken(toker, TokenKeyword.VAR));
        
	n.typenode = (NodeType) NodeType.parse(toker);
	n.type = n.typenode.getType();
	n.addNode(n.typenode);

	n.name = n.getIdent(toker).getIdent();

        // docstring
        if (toker.peek() instanceof TokenStringLiteral) {
            TokenStringLiteral t = (TokenStringLiteral) n.eatToken(toker);
            n.docstring = t.getString();
        }

        n.requireToken(toker, TokenPunct.SCOLON);

	return n;
    }

    public void asS2 (Indenter o) 
    {
        o.tabwrite("var ");
	typenode.asS2(o);
	o.write(" " + name);
        if (docstring != null) {
            o.write(BackendPerl.quoteString(" " + docstring));
        }
        o.writeln(";");
    }

    public String asString () 
    {
	return type.toString() + " " + name;
    }

};
