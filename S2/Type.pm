#!/usr/bin/perl
#

package S2::Type;

use strict;
use S2::Node;
use S2::Type;
use vars qw($VOID $STRING $INT $BOOL);

$VOID   = new S2::Type("void");
$STRING = new S2::Type("string");
$INT    = new S2::Type("int");
$BOOL   = new S2::Type("bool");

sub new {
    my ($class, $base) = @_;
    my $this = {
        'baseType' => $base,
        'typeMods' => "",
    };
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

    die "FIXME";
}

sub equals {
    my ($this, $o) = @_;
    return 0 unless $o->isa('S2::Type');
    return
        $o->{'baseType'} eq $this->{'baseType'} &&
        $o->{'typeMods'} eq $this->{'typeMods'};
}

sub sameMods {
    my ($class, $a, $b) = @_;
    return $a->{'typeMods'} eq $b->{'typeMods'};
}

sub makeArrayOf {
    my ($this) = @_;
    $this->{'typeMods'} .= "[]";
}

sub makeHashOf {
    my ($this) = @_;
    $this->{'typeMods'} .= "{}";
}

sub removeMod {
    my ($this) = @_;
    $this->{'typeMods'} =~ s/..$//;
}

sub isSimple {
    my ($this) = @_;
    return ! length $this->{'typeMods'};
}

sub isHashOf {
    my ($this) = @_;
    return $this =~ /\{\}$/;
}

sub isArrayOf {
    my ($this) = @_;
    return $this =~ /\[\]$/;
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
        my $base = shift;
        $t = S2::Type->new($base);
    }
    return $t->equals($STRING) ||
        $t->equals($INT) ||
        $t->equals($BOOL);
}

sub isReadOnly {
    shift->{'readOnly'};
}

sub setReadOnly {
    shift->{'readOnly'} = shift;
}


