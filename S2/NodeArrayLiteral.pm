#!/usr/bin/perl
#

package S2::NodeArrayLiteral;

use strict;
use S2::Node;
use S2::NodeExpr;
use vars qw($VERSION @ISA);

$VERSION = '1.0';
@ISA = qw(S2::Node);

sub new {
    my ($class) = @_;
    my $node = new S2::Node;
    $node->{'keys'} = [];
    $node->{'vals'} = [];
    bless $node, $class;
}

sub canStart {
    my ($class, $toker) = @_;
    return $toker->peek() == $S2::TokenPunct::LBRACK ||
        $toker->peek() == $S2::TokenPunct::LBRACE;
}

# [ <NodeExpr>? (, <NodeExpr>)* ,? ]
# { (<NodeExpr> => <NodeExpr> ,)* }

sub parse {
    my ($this, $toker) = @_;

    my $nal = new S2::NodeArrayLiteral;

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
                nal.addNode(ne);

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

__END__

package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;


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
