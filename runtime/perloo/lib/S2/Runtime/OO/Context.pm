
package S2::Runtime::OO::Context;
use strict;

# TODO: Make this "use fields"
# For now, just keep the internals private so it can be changed later

use constant VTABLE => 0;
use constant STATIC => 1;
use constant PROPS => 2;
use constant SCRATCH => 3;
use constant CALLBACK => 4;

use constant PRINT => 0;
use constant PRINT_SAFE => 1;
use constant ERROR => 2;

sub new {
    my ($class, @layers) = @_;
    
    my $vtable = {};
    my $props = {};
    my $callbacks = [sub{},sub{},sub{}];

    ## Copy the functions and props from each layer in turn
    foreach my $lay (@layers) {

        my $functions = $lay->get_functions();
        foreach my $fn (keys %{$functions}) {
            $vtable->{$fn} = $functions->{$fn};
        }
        
        my $propsets = $lay->get_property_sets();
        foreach my $pn (keys %{$propsets}) {
            $props->{$pn} = $propsets->{$pn};
        }
    }

    my $self = [$vtable, undef, $props, {}, $callbacks];
    return bless $self, $class;
}

sub set_print {
    my ($self, $print, $safe_print) = @_;
    
    $safe_print ||= $print;
    $self->[CALLBACK][PRINT] = $print;
    $self->[CALLBACK][PRINT_SAFE] = $safe_print;
}

sub set_error_handler {
    my ($self, $cb) = @_;

    $self->[CALLBACK][ERROR] = $cb;
}

sub run {
    my ($self, $fn, @args) = @_;
    
    $self->[VTABLE]{$fn}->($self, @args);
}


# Functions called from layer code at runtime. Not public API.

sub _print {
    $_[0]->[CALLBACK][PRINT]->(@_);
}

sub _print_safe {
    $_[0]->[CALLBACK][PRINT_SAFE]->(@_);
}

sub _call_function {
    my ($self, $func, $args, $layer, $srcline) = @_;
    
    $self->_error("Unknown function $func", $layer, $srcline) unless defined $_[0]->[VTABLE]{$func};
    
    $_[0]->[VTABLE]{$func}->($self, @$args);
}

sub _call_method {
    my ($self, $obj, $meth, $class, $is_super, $args, $layer, $srcline) = @_;
    
    if (ref $obj ne "HASH" || $obj->{_isnull}) {
        $self->_error("Method called on null $class object", $layer, $srcline);
    }

    $class = $obj->{_type} unless $is_super;
    return $self->_call_function("${class}::${meth}", [$obj, @$args], $layer, $srcline);
}

sub _get_properties {
    return $_[0]->[PROPS];
}

sub _error {
    $_[0]->[CALLBACK][ERROR]->(@_);
}

1;
