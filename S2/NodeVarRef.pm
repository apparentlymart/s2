#!/usr/bin/perl
#

package S2::NodeVarRef;

use strict;
use warnings;
use Carp;
use S2::Node;
use S2::NodeExpr;
use S2::Type;
use vars qw($VERSION @ISA $LOCAL $OBJECT $PROPERTY);

$LOCAL = 1;
$OBJECT = 2;
$PROPERTY = 3;
$VERSION = '1.0';
@ISA = qw(S2::Node);

sub new {
    my ($class) = @_;
    my $n = new S2::Node;
    bless $n, $class;
}

sub canStart {
    my ($class, $toker) = @_;
    return $toker->peek() == $S2::TokenPunct::DOLLAR;
}

sub parse {
    my ($class, $toker) = @_;

    my $n = new S2::NodeVarRef();
    $n->{'levels'} = [];
    $n->{'type'} = $LOCAL;

    # voo-doo so tokenizer won't continue parsing a string
    # if we're in a string and trying to parse interesting things
    # involved in a VarRef:
    
    $n->setStart($n->requireToken($toker, $S2::TokenPunct::DOLLAR, 0));

    $toker->pushInString(0);  # pretend we're not, even if we are.
    
    if ($toker->peekChar() eq "{") {
        $n->requireToken($toker, $S2::TokenPunct::LBRACE, 0);
        $n->{'braced'} = 1;
    } else {
        $n->{'braced'} = 0;
    }

    if ($toker->peekChar() eq ".") {
        $n->requireToken($toker, $S2::TokenPunct::DOT, 0);
        $n->{'type'} = $OBJECT;
    } elsif ($toker->peekChar() eq "*") {
        $n->requireToken($toker, $S2::TokenPunct::MULT, 0);
        $n->{'type'} = $PROPERTY;
    } 

    my $requireDot = 0;
    
    # only peeking at characters, not tokens, otherwise
    # we could force tokens could be created in the wrong 
    # context.  
    while ($toker->peekChar() =~ /[a-zA-Z\_\.]/)
    {
        if ($requireDot) {
            $n->requireToken($toker, $S2::TokenPunct::DOT, 0);
        } else {
            $requireDot = 1;
        }
        
        my $ident = $n->getIdent($toker, 1, 0);

        my $vl = {
            'var' => $ident->getIdent(),
            'derefs' => [],
        };

        # more preventing of token peeking:
        while ($toker->peekChar() eq '[' ||
               $toker->peekChar() eq '{') 
        {
            my $dr = {}; # Deref, 'type', 'expr'
            my $t = $n->eatToken($toker, 0);
        
            if ($t == $S2::TokenPunct::LBRACK) {
                $dr->{'type'} = '[';
                $n->addNode($dr->{'expr'} = S2::NodeExpr->parse($toker));
                $n->requireToken($toker, $S2::TokenPunct::RBRACK, 0);
            } elsif ($t == $S2::TokenPunct::LBRACE) {
                $dr->{'type'} = '{';
                $n->addNode($dr->{'expr'} = S2::NodeExpr->parse($toker));
                $n->requireToken($toker, $S2::TokenPunct::RBRACE, 0);
            } else {
                die;
            }
            
            push @{$vl->{'derefs'}}, $dr;
        }
        
        push @{$n->{'levels'}}, $vl;
    } # end while

    # did we parse just $ ?
    S2::error($n, "Malformed variable reference") unless
        @{$n->{'levels'}};    

    if ($n->{'braced'}) {
        # false argument necessary to prevent peeking at token
        # stream while it's in the interpolated variable parsing state,
        # else the string text following the variable would be
        # treated as if it were outside the string.
        $n->requireToken($toker, $S2::TokenPunct::RBRACE, 0);
    }

    $toker->popInString();  # back to being in a string if we were
    
    # now we must skip white space that requireToken above would've
    # done had we not told it not to, but not if the main tokenizer
    # is in a quoted string
    if ($toker->{'inString'} == 0) {
        $n->skipWhite($toker);
    }
    return $n;
}

# if told by NodeTerm.java, add another varlevel to point to
# this object's $.as_string
sub useAsString {
    my $this = shift;
    push @{$this->{'levels'}}, {
        'var' => 'as_string',
        'derefs' => [],
    };
}

sub isHashElement {
    my $this = 0;

    return 0 unless @{$this->{'levels'}};
    my $l = $this->{'levels'}->[-1];
    return 0 unless @$l;
    my $d = $l->[-1];
    return $d->{'type'} eq "{";
}

sub _getType {
    my ($this, $ck, $wanted) = @_;

    if (defined $wanted) {
        my $t = getType($this, $ck);
        return $t unless
            $wanted->equals($S2::Type::STRING);
        my $type = $t->toString();
        if ($ck->classHasAsString($type)) {
            $this->{'useAsString'} = 1;
            return $S2::Type::STRING;
        }
    }

    # must have at least reference something.
    return undef unless @{$this->{'levels'}};

    my @levs = @{$this->{'levels'}};
    my $lev = shift @levs;  # VarLevel
    my $vart = undef;  # Type

    # properties
    if ($this->{'type'} == $PROPERTY) {
        $vart = $ck->propertyType($lev->{'var'});
        S2::error($this, "Unknown property") unless $vart;
        $vart = $vart->clone();
    }

    # local variables.
    if ($this->{'type'} == $LOCAL) {
        $vart = $ck->localType($lev->{'var'});
        S2::error($this, "Unknown local variable \$$lev->{'var'}") unless $vart;
    }

    # properties & locals
    if ($this->{'type'} == $PROPERTY ||
        $this->{'type'} == $LOCAL) 
    {
        $vart = $vart->clone();
        
        # dereference [] and {} stuff
        $this->doDerefs($ck, $lev->{'derefs'}, $vart);
        
        # if no more levels, return now.  otherwise deferencing
        # happens below.
        return $vart unless @levs;
        $lev = shift @levs;
    }
     
    # initialize the name of the current object
    if ($this->{'type'} == $OBJECT) {
        my $curclass = $ck->getCurrentFunctionClass();
        S2::error($this, "Can't reference member variable in non-class function") unless $curclass;
        $vart = new S2::Type($curclass);
    }
        
    while ($lev) {
        my $nc = $ck->getClass($vart->toString());
        S2::error($this, "Can't use members of an undefined class") unless $nc;
        $vart = $nc->getMemberType($lev->{'var'});
        S2::error($this, "Can't find member '$lev->{'var'}' in " . $nc->getName()) unless $vart;
        $vart = $vart->clone();
        
        # dereference [] and {} stuff 
        $this->doDerefs($ck, $lev->{'derefs'}, $vart);
        $lev = shift @levs;
    }
    return $vart;
}

sub getType
{
    my ($self, $checker, $wanted) = @_;

    return ($self->{my_type} = $self->_getType($checker, $wanted));
}

# private
sub doDerefs {
    my ($this, $ck, $derefs, $vart) = @_;
    foreach my $d (@{$derefs}) {
        my $et = $d->{'expr'}->getType($ck);
        if ($d->{'type'} eq "{") {
            S2::error($this, "Can't dereference a non-hash as a hash")
                unless $vart->isHashOf();
            S2::error($this, "Must dereference a hash with a string or int")
                unless ($et->equals($S2::Type::STRING) ||
                        $et->equals($S2::Type::INT));
            $vart->removeMod();  # not a hash anymore
        } elsif ($d->{'type'} eq "[") {
            S2::error($this, "Can't dereference a non-array as an array ")
                unless $vart->isArrayOf();
            S2::error($this, "Must dereference an array with an int")
                unless $et->equals($S2::Type::INT);
            $vart->removeMod();  # not an array anymore
        }
    }
}

# is this variable $super ?
sub isSuper {
    my ($this) = @_;
    return 0 if $this->{'type'} != $LOCAL;
    return 0 if @{$this->{'levels'}} > 1;
    my $v = $this->{'levels'}->[0];
    return ($v->{'var'} eq "super" &&
            @{$v->{'derefs'}} == 0);
}

sub asS2 {
    my ($this, $o) = @_;
    die "Unported";
}

sub asPerl {
    my ($this, $bp, $o) = @_;
    my $first = 1;

    if ($this->{'type'} == $LOCAL) {
        $o->write("\$");
    } elsif ($this->{'type'} == $OBJECT) {
        $o->write("\$this");
    } elsif ($this->{'type'} == $PROPERTY) {
        if ($bp->oo) {
            # This is a bit lame, but the expression here
            # must be an lvalue so returning the whole hashtable
            # is the only way to go to avoid hardcoding the internals
            # of the context object.
            $o->write("\$_ctx->_get_properties()");
        }
        else {
            $o->write("\$_ctx->[PROPS]");
        }
        $first = 0;
    }

    foreach my $lev (@{$this->{'levels'}}) {
        if (! $first || $this->{'type'} == $OBJECT) {
            $o->write("->{'$lev->{'var'}'}");
        } else {
            my $v = $lev->{'var'};
            if ($first && $this->{'type'} == $LOCAL &&
                $v eq "super") {
                $v = "this";
            }
            $o->write($v);
            $first = 0;
        }

        foreach my $d (@{$lev->{'derefs'}}) {
            $o->write("->$d->{'type'}"); # [ or {
            $d->{'expr'}->asPerl($bp, $o);
            $o->write($d->{'type'} eq "[" ? "]" : "}");
        }
    } # end levels

    if ($this->{'useAsString'}) {
        $o->write("->{'as_string'}");
    }
}

#
#   Returns the literal value of this variable reference (i.e. not an lvalue!)
#   If you supply a source register, then this emits a store. Otherwise, it
#   emits a load.
#
#   TODO: Autovivification!
#

sub asParrot
{
    my ($self, $backend, $general, $main, $data) = @_;
    my $src_register = $data->{src_register}; delete $data->{src_register};

    my @levels = @{$self->{levels}};

    # We sort this level stuff out by building up a list of ops.
    my @ops;
    my $first = 1;

    foreach my $level (@levels) {
        my $op = { type => 'get_member', key => $level->{var} };

        if ($first) {
            if ($self->{type} == $LOCAL) {
                if ($op->{key} eq 'this') {
                    $op->{type} = 'get_self';
                } elsif ($op->{key} eq 'super') {
                    $op->{type} = 'get_super';
                } else {
                    $op->{type} = 'get_local_var';
                }
            } elsif ($self->{type} == $OBJECT) {
                # This one becomes an op unto itself.
                push @ops, { type => 'get_self' };
            } elsif ($self->{type} == $PROPERTY) {
                $op->{type} = 'get_property';
            }

            $first = 0;
        }

        # if ($op->{type} eq 'get_member') {
        #     use Data::Dumper qw/Dumper/;
        #     print STDERR Dumper($level);
        #     exit;
        # }

        push @ops, $op if defined $op->{key};

        foreach my $array_or_hash_access (@{$level->{derefs}}) {
            push @ops, {
                type => 'get_keyed_item',
                key_expr => $array_or_hash_access->{expr}
            };
        }
    }

    if ($self->{useAsString}) {
        # If useAsString was specified, we get the "as_string" member, so tack
        # that op onto the end.
        push @ops, { type => 'get_member', key => 'as_string' };
    }

    # The very last op becomes a store if we're storing.
    my $store_op = (defined $src_register ? pop @ops : undef);

    my $reg;

    # Now do all the requested load operations.
    foreach my $load_op (@ops) {
        my $ops = {
            get_self => sub
            {
                $reg = 'myself';
            },
            get_super => sub
            {
                $reg = $backend->register('P');
                $general->writeln("$reg = new .Super, myself");
            },
            get_local_var => sub
            {
                $reg = '_s2l_' . $load_op->{key};
            },
            get_property => sub
            {
                $reg = $backend->register('P');
                $general->writeln(qq/$reg = find_global "_s2::properties", / .
                    $backend->quote($load_op->{key}));
            },
            get_member => sub
            {
                my $new_reg = $backend->register('P');

                $general->writeln("$new_reg = getattribute $reg, " .
                    $backend->quote('_' . $load_op->{key}));

                $reg = $new_reg;
            },
            get_keyed_item => sub
            {
                my $index_reg = $load_op->{key_expr}->asParrot($backend,
                    $general, $main, $data);
                my $new_reg = $backend->register('P');

                $general->writeln("$new_reg = ${reg}[$index_reg]");

                $reg = $new_reg;
            } 
        };

        &{$ops->{$load_op->{type}}}();
    }

    # And now the store operation, if it was requested.
    if (defined $store_op) {
        my $ops = {
            get_self => sub
            {
                croak "You can't change yourself like that";
            },
            get_local_var => sub
            {
                $general->writeln("_s2l_$store_op->{key} = $src_register");
            },
            get_property => sub
            {
                $general->writeln(qq/store_global "_s2::properties", / .
                    $backend->quote($store_op->{key}) . ", $src_register");
            },
            get_member => sub
            {
                my $src_pmc = $backend->require_pmc($general, $main,
                    $src_register);
                $general->writeln("setattribute $reg, " . $backend->quote('_'
                    . $store_op->{key}) . ", $src_pmc");
            },
            get_keyed_item => sub
            {
                my $index_reg = $store_op->{key_expr}->asParrot($backend,
                    $general, $main, $data);

                $general->writeln("${reg}[$index_reg] = $src_register");
            } 
        };

        &{$ops->{$store_op->{type}}}();
        $reg = $src_register;
    }

    $general->writeln("$reg = clone $reg") if
        $self->{my_type}->toString =~ /^int|string|bool$/;

    return $reg;
}

sub isProperty {
    my $this = shift;
    return $this->{'type'} == $PROPERTY;
}

sub propName {
    my $this = shift;
    return "" unless $this->{'type'} == $PROPERTY;
    return $this->{'levels'}->[0]->{'var'};
}
