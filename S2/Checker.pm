#!/usr/bin/perl
#

package S2::Checker;

use strict;

sub new
{
    my $class = shift;
    my $this = {
        'classes' => {},
        'props' => {},
        'funcs' => {},
        'funcBuiltin' => {},
        'derclass' => {},
        'localblocks' => [],
    };
    bless $this, $class;
}

sub addClass {
    my ($this, $name, $nc) = @_;
    $this->{'classes'}->{$name} = $nc;

    # make sure that the list of classes that derive from 
    # this one exists.
    $this->{'derclasses'}->{$name} ||= [];

    # and if this class derives from another, add ourselves
    # to that list
    my $parent = $nc->getParentName();
    if ($parent) {
        my $l = $this->{'derclasses'}->{$parent};
        die "Internal error: can't append to empty list" unless $l;
        push @$l, $name;
    }
}

sub getClass {
    my ($this, $name) = @_;
    return undef unless $name;
    return $this->{'classes'}->{$name};
}

sub getParentClassName {
    my ($this, $name) = @_;
    my $nc = $this->getClass($name);
    return undef unless $nc;
    return $nc->getParentName();
}

sub isValidType {
    my ($this, $t) = @_;
    return 0 unless $t;
    return 1 if $t->isPrimitive();
    return defined $this->getClass($t->baseType());
}

# property functions
sub addProperty {
    my ($this, $name, $t) = @_;
    $this->{'props'}->{$name} = $t;
}

sub propertyType {
    my ($this, $name) = @_;
    return $this->{'props'}->{$name};
}

# return type functions (undef means no return type)
sub setReturnType {
    my ($this, $t) = @_;
    $this->{'returnType'} = $t;
}

sub getReturnType {
    shift->{'returnType'};
}

# funtion functions
sub addFunction {
    my ($this, $funcid, $t, $builtin) = @_;
    my $existing = $this->functionType($funcid);
    if ($existing && ! $existing->equals($t)) {
        S2::error(undef, "Can't override function '$funcid' with new return type.");
    }
    $this->{'funcs'}->{$funcid} = $t;
    $this->{'funcBuiltin'}->{$funcid} = $builtin;
}

sub functionType {
    my ($this, $funcid) = @_;
    $this->{'funcs'}->{$funcid};
}

sub isFuncBuiltin {
    my ($this, $funcid) = @_;
    $this->{'funcBuiltin'}->{$funcid};
}

# returns true if there's a string -> t class constructor
sub isStringCtor {
    my ($this, $t) = @_;
    return 0 unless $t && $t->isSimple();
    my $cname = $t->baseType();
    my $ctorid = "${cname}::${cname}(string)";
    my $rt = $this->functionType($ctorid);
    return $rt && $rt->isSimple() && $rt->baseType() eq $cname &&
        $this->isFuncBuiltin($ctorid);
}

# setting/getting the current function class we're in
sub setCurrentFunctionClass { my $this = shift; $this->{'funcClass'} = shift; }
sub getCurrentFunctionClass { shift->{'funcClass'}; }

# setting/getting whether in a function now
sub setInFunction { my $this = shift; $this->{'inFunction'} = shift; }
sub getInFunction { shift->{'inFunction'}; }

# variable lookup
sub pushLocalBlock {
    my ($this, $nb) = @_;  # nb  = NodeStmtBlock
    push @{$this->{'localblocks'}}, $nb;
}
sub popLocalBlock {
    my ($this) = @_;
    pop @{$this->{'localblocks'}};
}

sub getLocalScope {
    my $this = shift;
    return undef unless @{$this->{'localblocks'}};
    return $this->{'localblocks'}->[-1];
}

sub localType {
    my ($this, $local) = @_;
    return undef unless @{$this->{'localblocks'}};
    foreach my $nb (reverse @{$this->{'localblocks'}}) {
        my $t = $nb->getLocalVar($local);
        return $t if $t;
    }
    return undef;
}

sub memberType {
    my ($this, $clas, $member) = @_;
    my $nc = $this->getClass($clas);
    return undef unless $nc;
    return $nc->getMemberType($member);
}

sub setHitFunction { my $this = shift; $this->{'hitFunction'} = shift; }
sub getHitFunction { shift->{'hitFunction'}; }

sub hasDerClasses {
    my ($this, $clas) = @_;
    return scalar @{$this->{'derclass'}->{$clas}};
}

sub getDerClasses {
    my ($this, $clas) = @_;
    return $this->{'derclass'}->{$clas};
}

# TODO: public void setFuncDistance

sub getFuncIDs {
    my ($this, $nf) = @_;
    return [ sort keys %{$this->{'funcIDs'}} ];
}

# per function
sub resetFunctionNums {
    my $this = shift;
    $this->{'funcNum'} = 0;
    $this->{'funcNums'} = {};
    $this->{'funcNames'} = [];
}

sub functionNum {
    my ($this, $funcID) = @_;
    my $num = $this->{'funcNums'}->{$funcID};
    unless (defined $num) {
        $num = ++$this->{'funcNum'};
        $this->{'funcNums'}->{$funcID} = $num;
        push @{$this->{'funcNames'}}, $funcID;
    }
    return $num;
}

sub getFuncNums { shift->{'funcNums'}; }
sub getFuncNames { shift->{'funcNames'}; }

# check if type 't' is a subclass of 'w'
sub typeIsa {
    my ($this, $t, $w) = @_;
    return 0 unless S2::Type->sameMods($t, $w);

    my $is = $t->baseType();
    my $parent = $w->baseType();
    while ($is) {
        return 1 if $is eq $parent;
        my $nc = $this->getClass($is);
        $is = $nc ? $nc->getParentName() : undef;
    }
    return 0;
}

# check to see if a class or parents has a "toString()" method
sub classHasToString {
    my ($this, $clas) = @_;
    my $et = $this->functionType("${clas}::toString()");
    return $et && $et->equals($S2::Type::STRING);
}

# check to see if a class or parents has an "as_string" string member
sub classHasAsString {
    my ($this, $clas) = @_;
    my $et = $this->memberType($clas, "as_string");
    return $et && $et->equals($S2::Type::STRING);
}

# ---------------

sub checkLayer {
    my ($this, $lay) = @_; # lay = Layer

    # initialize layer-specific data structures
    $this->{'funcDist'} = {};
    $this->{'funcIDs'} = {};
    $this->{'hitFunction'} = 0;

    # check to see that they declared the layer type, and that
    # it isn't bogus.
    {
        # what the S2 source says the layer is
        my $dtype = $lay->getDeclaredType();
        S2::error(undef, "Layer type not declared") unless $dtype;
        
        # what type s2compile thinks it is
        my $type = $lay->getType();

        S2::error(undef, "Layer is declared $dtype but expecting a $type layer")
            unless $type eq $dtype;

        # now that we've validated their type is okay
        $lay->setType($dtype);
    }

    my $nodes = $lay->getNodes();
    foreach my $n (@$nodes) {
        $n->check($lay, $this);
    }

    if ($lay->getType() eq "core") {
        my $mv = $lay->getLayerInfo("majorversion");
        unless (defined $mv) {
            S2::error(undef, "Core layers must declare 'majorversion' layerinfo.");
        }
    }
}

sub functionID {
    my ($clas, $func, $o) = @_;
    my $sb;
    $sb .= "${clas}::" if $clas;
    $sb .= "$func(";
    if (! defined $o) {
        # do nothing
    } elsif (ref $o && $o->isa('S2::NodeFormals')) {
        $sb .= $o->typeList();
    } else {
        $sb .= $o;
    }
    $sb .= ")";
    return $sb;
}


1;
