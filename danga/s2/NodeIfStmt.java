package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;

public class NodeIfStmt extends Node
{
    NodeExpr expr;
    NodeStmtBlock thenblock;
    NodeStmtBlock elseblock;
    LinkedList elseifexprs;
    LinkedList elseifblocks;
    
    public static boolean canStart (Tokenizer toker) throws Exception
    {	
	if (toker.peek().equals(TokenKeyword.IF))
	    return true;
	return false;
    }
    
    public static Node parse (Tokenizer toker) throws Exception
    {
	NodeIfStmt n = new NodeIfStmt();
	n.elseifblocks = new LinkedList();
	n.elseifexprs = new LinkedList();

	n.setStart(n.requireToken(toker, TokenKeyword.IF));
	n.requireToken(toker, TokenPunct.LPAREN);
	n.addNode(n.expr = (NodeExpr) NodeExpr.parse(toker));
	n.requireToken(toker, TokenPunct.RPAREN);
	n.addNode(n.thenblock = (NodeStmtBlock) NodeStmtBlock.parse(toker));

	while (toker.peek().equals(TokenKeyword.ELSEIF)) {
	    n.eatToken(toker);

	    // get the expression.
	    n.requireToken(toker, TokenPunct.LPAREN);
	    Node expr = NodeExpr.parse(toker);
	    n.addNode(expr);
	    n.requireToken(toker, TokenPunct.RPAREN);
	    n.elseifexprs.add(expr);

	    // and the block
	    Node nie = NodeStmtBlock.parse(toker);
	    n.addNode(nie);
	    n.elseifblocks.add(nie);
	}

	if (toker.peek().equals(TokenKeyword.ELSE)) {
	    n.eatToken(toker);
	    n.addNode(n.elseblock = (NodeStmtBlock) NodeStmtBlock.parse(toker));
	}

	return n;
    }

    // returns true if and only if the 'then' stmtblock ends in a
    // return statement, the 'else' stmtblock is non-null and ends
    // in a return statement, and any elseif stmtblocks end in a return
    // statement.
    public boolean willReturn () 
    {
	// there must be an else block.
	if (elseblock == null) return false;

	// both the 'then' and 'else' blocks must return
	if (! thenblock.willReturn()) return false;
	if (! elseblock.willReturn()) return false;

	// if there are elseif blocks, all those must return
	ListIterator li = elseifblocks.listIterator();
	while (li.hasNext()) {
	    NodeStmtBlock sb = (NodeStmtBlock) li.next();
	    if (! sb.willReturn()) return false;
	}

	// else, it does return.
	return true;
    }

    public void check (Layer l, Checker ck) throws Exception
    {
	Type t = expr.getType(ck);
	if (! t.equals(Type.BOOL) && ! t.equals(Type.INT)) {
	    throw new Exception("Non-boolean if test at "+getFilePos());
	}
	thenblock.check(l, ck);

	ListIterator li;

	li = elseifexprs.listIterator();
	while (li.hasNext()) {
	    NodeExpr ne = (NodeExpr) li.next();
	    t = ne.getType(ck);
	    if (! t.equals(Type.BOOL) && ! t.equals(Type.INT))
		throw new Exception("Non-boolean elseif test at "+ne.getFilePos());
	}

	li = elseifblocks.listIterator();
	while (li.hasNext()) {
	    NodeStmtBlock sb = (NodeStmtBlock) li.next();
	    sb.check(l, ck);
	}
	
	if (elseblock != null)
	    elseblock.check(l, ck);
    }

    public void asS2 (Indenter o)
    {
	// if
	o.tabwrite("if (");
	expr.asS2(o);
	o.write(") ");
	thenblock.asS2(o);
	
	// else-if
	ListIterator li = elseifexprs.listIterator(0);
	ListIterator lib = elseifblocks.listIterator(0);
	while (li.hasNext()) {
	    NodeExpr expr = (NodeExpr) li.next();
	    NodeStmtBlock block = (NodeStmtBlock) lib.next();

	    o.write(" elseif (");
	    expr.asS2(o);
	    o.write(") ");
	    block.asS2(o);
	}
	

	// else
	if (elseblock != null) {
	    o.write(" else ");
	    elseblock.asS2(o);
	}
	o.newline();
    }

    public void asPerl (BackendPerl bp, Indenter o)
    {
	// if
	o.tabwrite("if (");
	expr.asPerl(bp, o);
	o.write(") ");
	thenblock.asPerl(bp, o);
	
	// else-if
	ListIterator li = elseifexprs.listIterator(0);
	ListIterator lib = elseifblocks.listIterator(0);
	while (li.hasNext()) {
	    NodeExpr expr = (NodeExpr) li.next();
	    NodeStmtBlock block = (NodeStmtBlock) lib.next();
	    o.write(" elsif (");
	    expr.asPerl(bp, o);
	    o.write(") ");
	    block.asPerl(bp, o);
	}
	

	// else
	if (elseblock != null) {
	    o.write(" else ");
	    elseblock.asPerl(bp, o);
	}
	o.newline();
    }

};

