package danga.s2;

public class NodeStmt extends Node
{
    public static boolean canStart (Tokenizer toker) throws Exception
    {
	if (NodePrintStmt.canStart(toker) ||
	    NodeIfStmt.canStart(toker) ||
	    NodeReturnStmt.canStart(toker) ||
	    NodeDeleteStmt.canStart(toker) ||
	    NodeForeachStmt.canStart(toker) ||
	    NodeVarDeclStmt.canStart(toker) ||
	    NodeExprStmt.canStart(toker) ||
	    false)
	    return true;
	return false;
    }

    public static Node parse (Tokenizer toker) throws Exception
    {
	if (NodePrintStmt.canStart(toker))
	    return NodePrintStmt.parse(toker);

	if (NodeIfStmt.canStart(toker))
	    return NodeIfStmt.parse(toker);

	if (NodeReturnStmt.canStart(toker))
	    return NodeReturnStmt.parse(toker);

	if (NodeDeleteStmt.canStart(toker))
	    return NodeDeleteStmt.parse(toker);

	if (NodeForeachStmt.canStart(toker))
	    return NodeForeachStmt.parse(toker);

	if (NodeVarDeclStmt.canStart(toker))
	    return NodeVarDeclStmt.parse(toker);

	// important that this is last: 
	//(otherwise idents would be seen as function calls)
	if (NodeExprStmt.canStart(toker))
	    return NodeExprStmt.parse(toker);
	    
	throw new Exception("don't know how to parse this type of statement");
    }


};
