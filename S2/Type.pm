#!/usr/bin/perl
#

package S2::Type;

use strict;
use S2::Node;
use S2::Type;
use vars qw($VOID $STRING $INT $BOOL);

$VOID   = new S2::Type("void", 1);
$STRING = new S2::Type("string", 1);
$INT    = new S2::Type("int", 1);
$BOOL   = new S2::Type("bool", 1);

sub new {
    my ($class, $base, $final) = @_;
    my $this = {
        'baseType' => $base,
        'typeMods' => "",
    };
    $this->{'final'} = 1 if $final;
    bless $this, $class;
}

sub clone {
    my $this = shift;
    my $nt = S2::Type->new($this->{'baseType'});
    $nt->{'typeMods'} = $this->{'typeMods'};
    $nt->{'readOnly'} = $this->{'readOnly'};
    return $nt;
}

# return true if the type is an INT or BOOL (something
# that can be interpretted in a boolean context)
sub isBoolable {
    my $this = shift;
    return $this->equals($BOOL) || $this->equals($INT);
}

sub subTypes {
    my ($this, $ck) = @_;
    my $l = [];

    my $nc = $ck->getClass($this->{'baseType'});
    unless ($nc) {
        # no sub-classes.  just return our type.
        push @$l, $this;
        return $l;
    }

    foreach my $der (@{$nc->getDerClasses()}) {
        # add a copy of this type to the list, but with
        # the derivative class type.  that way it
        # saves the varlevels:  A[] .. B[] .. C[], etc
        my $c = $der->{'nc'}->getName();
        my $newt = $this->clone();
        $newt->{'baseType'} = $c;
        push @$l, $newt;
    }

    return $l;
}

sub equals {
    my ($this, $o) = @_;
    return unless $o->isa('S2::Type');
    return $o->{'baseType'} eq $this->{'baseType'} &&
        $o->{'typeMods'} eq $this->{'typeMods'};
}

sub sameMods {
    my ($class, $a, $b) = @_;
    return $a->{'typeMods'} eq $b->{'typeMods'};
}

sub makeArrayOf {
    my ($this) = @_;
    S2::error('', "Internal error") if $this->{'final'};
    $this->{'typeMods'} .= "[]";
}

sub makeHashOf {
    my ($this) = @_;
    S2::error('', "Internal error") if $this->{'final'};
    $this->{'typeMods'} .= "{}";
}

sub removeMod {
    my ($this) = @_;
    S2::error('', "Internal error") if $this->{'final'};
    $this->{'typeMods'} =~ s/..$//;
}

sub isSimple {
    my ($this) = @_;
    return ! length $this->{'typeMods'};
}

sub isHashOf {
    my ($this) = @_;
    return $this->{'typeMods'} =~ /\{\}$/;
}

sub isArrayOf {
    my ($this) = @_;
    return $this->{'typeMods'} =~ /\[\]$/;
}

sub baseType {
    shift->{'baseType'};
}

sub toString {
    my $this = shift;
    "$this->{'baseType'}$this->{'typeMods'}";
}

sub isPrimitive {
    my $arg = shift;
    my $t;
    if (ref $arg) { $t = $arg; }
    else {
        $t = S2::Type->new($arg);
    }
    return $t->equals($STRING) ||
        $t->equals($INT) ||
        $t->equals($BOOL);
}

sub isReadOnly {
    shift->{'readOnly'};
}

sub setReadOnly {
    my ($this, $v) = @_;
    S2::error('', "Internal error") if $this->{'final'};
    $this->{'readOnly'} = $v;
}


