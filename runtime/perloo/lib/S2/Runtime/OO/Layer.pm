
package S2::Runtime::OO::Layer;
use strict;

sub new {
    my $self = {
        'info' => {},
        'prop' => {},
        'propset' => {},
        'propgroup' => [],
        'propgroup_members' => {},
        'propgroup_name' => {},
        'func' => {},
        'classdoc' => {},
        'globfuncdoc' => {},
        'sourcename' => {},
    };

    return bless $self, shift;
}

sub get_functions {
    return $_[0]->{func};
}

sub get_property_sets {
    return $_[0]->{propset};
}

# These methods called by S2 layer code during load. Not public API.

sub set_source_name {
    my ($self, $name) = @_;
    
    $self->{sourcename} = $name;
}

sub set_layer_info {
    my ($self, $key, $value) = @_;
    
    $self->{info}{$key} = $value;
}

sub register_class {
    my ($self, $name, $doc) = @_;
    
    $self->{classdoc}{$name} = $doc;
}

sub register_global_function {
    my ($self, $sig, $rettype, $doc, $attr) = @_;
    
    $self->{globfuncdoc}{$sig} = {
        "return" => $rettype,
        "docstring" => $doc,
        "attr" => { map({ $_ => 1 } split(/,/, $attr)) },
    };
}

sub register_propgroup_name {
    my ($self, $ident, $name) = @_;
    
    $self->{propgroup_name}{$ident} = $name;
}

sub register_property {
    my ($self, $name, $attr) = @_;
    
    $self->{prop}{$name} = $attr;
}

sub register_set {
    my ($self, $name, $value) = @_;

    $self->{propset}{$name} = $value;
}

sub register_function {
    my ($self, $sigs, $code) = @_;

    my $impl = $code->();
    
    foreach my $sig (@$sigs) {
        $self->{func}{$sig} = $impl;
    }
}

1;
