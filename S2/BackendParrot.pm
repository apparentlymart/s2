#!/usr/bin/perl
#
#  S2 backend for Parrot Intermediate Language (PIL).
#

package S2::BackendParrot;

use strict;
use warnings FATAL => 'all';
use S2::OutputScalar;

sub new
{
    my ($class, $layer, $layer_id, $is_untrusted) = @_;

    my $self = {
        layer       => $layer,
        layerID     => $layer_id,
        untrusted   => $is_untrusted,
        'package'   => '',
    };

    eval "use S2::Parrot::System";

    bless $self, $class;
    return $self;
}

sub getBuiltinPackage
{
    my ($self) = @_;

    return $self->{'package'};
}

sub setBuiltinPackage
{
    my ($self, $package) = @_;

    $self->{'package'} = $package;
}

sub getLayerID
{
    my ($self) = @_;

    return $self->{layerID} || 1;
}

sub getLayerIDString
{
    my ($self) = @_;

    return $self->getLayerID();
}

sub untrusted
{
    my ($self) = @_;

    return $self->{untrusted};
}

sub mangle
{
    my ($self, $signature) = @_;

    return S2::mangle($signature);
}

#
#   Writes the initialization stub - that is, the very first thing that gets
#   called. Its job is to clean up the _s2:: namespace by deleting any classes
#   that might be left over from a previous run.
#
#   TODO: Do cleanup duties at the end, as they should be done.
#
sub write_init_stub
{
    my ($self, $general, $main) = @_;

    $main->writeln(<<'END_INIT_STUB');
# errorsoff 1     # PARROT_ERRORS_GLOBALS_FLAG
# gc_debug 1 

$P0 = getinterp
$P0 = $P0[0]    # IGLOBALS_CLASSNAME_HASH
if_null $P0, iter_end
$P1 = new .Iterator, $P0
set $P1, 0
iter_loop:
    unless $P1, iter_end
    $S0 = shift $P1
    $I0 = index $S0, "_s2::_"
    ne $I0, 0, iter_loop
    delete $P0[$S0]
    goto iter_loop
iter_end:
END_INIT_STUB
}

#
#   Writes the call stub, which cleanly handles calling from Perl to Parrot.
#   This is better than calling directly from CoreEmbedded because the call
#   stub does its best to prevent bad S2 code from bringing down the Parrot
#   interpreter and the process with it.
#
#   TODO: We should be able to call methods too.
#
sub write_call_stub
{
    my ($self, $general, $main) = @_;

    $general->writeln(<<'END_CALL_STUB');
.namespace [ "_s2" ]

.sub call_stub
.param pmc meth
.param pmc target
.param pmc args
                push_eh except
                $P0 = meth
                $P0(args :flat)
                clear_eh
                $P0 = new .Undef
                .return($P0)
except:         get_results '(0,0)', $P0, $S0 
                .return($S0)
.end
END_CALL_STUB

    return 1;
}

sub output
{
    my ($self, $stream) = @_;

    $stream->writeln(<<END_HEADER);
#!/usr/local/bin/parrot
#
#   Parrot PIR file for @{[ defined($self->{layerID}) ?
        "S2 layer ID $self->{layerID}" :
        'an anonymous S2 layer' ]}, automatically generated
#   at @{[ scalar localtime ]}.
#   Do not modify this file. Modify the layer instead.
#
END_HEADER

    my $main_stream;
    my $main_scalar = '';
    $main_stream = S2::OutputScalar->new(\$main_scalar);

    $self->write_init_stub($stream, $main_stream);
    $self->write_call_stub($stream, $main_stream);

    foreach my $node (@{$self->{layer}->getNodes}) {
        $node->asParrot($self, $stream, $main_stream);
    }

    $stream->writeln('.namespace [ "_s2" ]');
    $stream->writeln('.sub _s2_init');
    $stream->writeln($main_scalar);
    $stream->writeln('.end');

    $stream->writeln('.sub main :main');
    $stream->writeln('.param pmc argv :slurpy');
    $stream->writeln('$P0 = find_global "_core_embedded", "_call_perl"');
    $stream->writeln('$P1 = new .ResizablePMCArray');
    $stream->writeln('$P0($P1, "S2::BackendParrot::main_springback")');
    $stream->writeln('.end');

    $stream->writeln("\n# End of file.");

    return 1;
}

sub main_springback
{
    print STDERR "DYING.\n";
    S2::run_code(undef, 'main()');
}

sub quote
{
    my ($self) = shift;

    my $str = join '', @_;
    $str =~ s/"/\\"/g;
    $str =~ s/\n/\\n/g;
    $str =~ s/([^\x00-\x80])/sprintf '\\{%x}', ord $1/eg;

    return '"' . $str . '"'; 
}

#
#   In the future, this may be expanded to use int and string registers
#   for speed, but let's make it correct before we make it fast.
#
sub pir_type
{
    my ($self, $s2_type) = @_;

    return 'pmc';
}

sub register
{
    my ($self, $type) = @_;

    $self->{registers} = {} unless defined $self->{registers};
    return '$' . $type . (($self->{registers}{$type}++) + 0);
}

sub register_for_s2_type
{
    my ($self, $s2_type) = @_;

    return $self->register('P');
}

sub identifier
{
    my ($self, $in_main) = @_;

    # Magical auto-increment
    if ($in_main) {
        $self->{last_main_identifier} = 'a' if not defined
            $self->{last_main_identifier};
        return ('_s2_mainid_' . $self->{last_main_identifier}++);
    } else {
        $self->{last_identifier} = 'a' if not defined
            $self->{last_identifier};
        return ('_s2_id_' . $self->{last_identifier}++);
    }
}

sub reset_generators
{
    my ($self) = @_;

    delete $self->{registers};
    delete $self->{last_identifier};
}

sub require_pmc
{
    my ($self, $general, $main, $register) = @_;

    return $register if $register =~ /^\$P\d+$/;

    my $pmc_reg = $self->register('P');

    $general->writeln("$pmc_reg = $register");
    return $pmc_reg;
}

#
#   Returns PIR code to initialize an S2 variable appropriately. aux_register
#   is an auxiliary register for the function to use. If it's not supplied,
#   initialize_s2_type will use the register() method to allocate one.
#
#   TODO: Make sure this jives with the Perl backend behavior.
#
sub initialize_s2_type
{
    my ($self, $register, $s2type, $aux_register) = @_;

    my $code = '';

    if ($s2type =~ /(\[\]|\{\})/) {
        if ($1 eq '[]') {
            $code .= "$register = new .ResizablePMCArray\n";
        } else {
            $code .= "$register = new .Hash\n";
        }
    } elsif ($s2type eq 'int') {
        $code .= qq/$register = new .Integer, "0"\n/;
    } elsif ($s2type eq 'string') {
        $code .= qq/$register = new .String, ""\n/;
    } else {
        $code .= qq/$register = new .Undef\n/;
    }

    return $code;
}

#
#   Constructs a "stringy" object, or one that can be constructed with a string
#   (that is, a Color).
#
sub construct_stringy
{
    my ($self, $general, $main, $string_register, $class) = @_;

    my $cons_reg = $self->register('P');
    my $out_reg = $self->instantiate($general, $class);

    $general->writeln(qq/$cons_reg = find_global "_s2::_$class", / .
        $self->quote($self->mangle("$class(string)")));

    $general->writeln("$out_reg = $out_reg.$cons_reg($string_register)");

    return $out_reg;
}

# Instantiates an S2 object of the given class.
sub instantiate
{
    my ($self, $stream, $class, $register) = @_;

    $register = $self->register('P') if not defined $register;

    $stream->writeln(qq/$register = new "_s2::_$class"/);

    return $register;
}

sub UNIVERSAL::asParrot
{
    my ($self) = @_;

    print STDERR "Warning: I don't know how to translate this " . ref($self) .
        " into Parrot.\n";

    return '';
}

1;

