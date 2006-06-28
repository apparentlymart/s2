#!/usr/bin/perl
#
#   Object-oriented interface to Parrot embedding in S2.
#

package S2::Parrot::Embedded;

use strict;
use warnings FATAL => 'all';

use Carp;
use Fcntl qw/F_SETFD/;
use File::Temp;
use IO::Handle;
use POSIX ':sys_wait_h';
use Socket;

use S2::Parrot::CoreEmbedded;

our $VERSION = 0.01;

sub new
{
    my ($class) = @_;

    my $self = {};
    
    S2::Parrot::CoreEmbedded::init_embedded_parrot(0x04, 0x0) or
        croak "Failed to initialize Parrot";

    bless $self, $class;
    return $self;
}

=head2 compile_pir

    $parrot->compile_pir(\$pir_code);

Given a reference to PIR code, compiles it and returns a reference to the
bytecode.

=cut

sub compile_pir
{
    my ($self, $pir_ref) = @_;

    my $pir_fh = File::Temp::tempfile();
    fcntl $pir_fh, F_SETFD, 0;
    print $pir_fh $$pir_ref;
    seek $pir_fh, 0, 0;
    sysseek $pir_fh, 0, 0;

    my $pbc_fh = File::Temp::tempfile();
    fcntl $pbc_fh, F_SETFD, 0;

    system('/usr/local/bin/parrot -O1 -o /dev/fd/' . fileno($pbc_fh) .
        ' --output-pbc /dev/fd/' . fileno($pir_fh))
        and croak 'Parrot compilation failed';

    sysseek $pbc_fh, 0, 0;

    my $pbc = '';
    my ($pos, $len) = (0, 0);
    
    $pos += $len while $len = sysread $pbc_fh, $pbc, 4096, $pos;

    return \$pbc;
}

sub load_pbc
{
    my ($self, $pbc_ref) = @_;

    S2::Parrot::CoreEmbedded::read_bytecode_into_embedded_parrot($pbc_ref) or
        croak "Failed to load bytecode";

    return 1;
}

sub start_pbc
{
    S2::Parrot::CoreEmbedded::run_bytecode_in_embedded_parrot(undef);
}

# FIXME
sub run_parrot_function
{
    my ($self, $name) = @_;

=pod
    my $gonna_die = 0;
    my ($errors, $output);

    # Open the I/O streams for our child process.
    my ($old_stderr, $trusted_output_fd);
    open $old_stderr, '>&', \*STDERR;
    close STDERR;

    open STDERR, '+>', undef;
    open $trusted_output_fd, '+>', undef;

    my $pid;
    if ($pid = fork) {
        waitpid $pid, 0;

        seek $trusted_output_fd, 0, 0;
        while (my $read = sysread $trusted_output_fd, $output, 4096) {
            &{&S2::get_output}($output);
        } continue {
            $output = '';
        }

        if ($?) {
            seek STDERR, 0, 0;
            my ($len, $read) = (0, 0);
            $len += $read while $read = sysread STDERR, $errors, 4096, $len;

            $gonna_die = 1;
        }
    } else {
        S2::set_output(sub { syswrite $trusted_output_fd, $_[0] });
        S2::set_output_safe(sub { syswrite $trusted_output_fd, $_[0] }); #FIXME

=cut
        S2::Parrot::CoreEmbedded::run_function_in_embedded_parrot($name, undef,
            undef);

=pod
        exit;
    }

    close STDERR;
    open STDERR, '>&', $old_stderr;

    confess $errors if $gonna_die;
=cut
}

sub init_perl_nci
{
    my ($self) = @_;

    S2::Parrot::CoreEmbedded::init_perl_nci();
}

sub init_layer
{
    my ($self) = @_;

    S2::Parrot::CoreEmbedded::run_function_in_embedded_parrot('_s2_init',
        undef, undef);
}

#
#   Returns the PIR code necessary to call a Perl function. $args_regs is a
#   reference to a list of PMC registers (e.g. [ '$P1', '$P2' ]) that contain
#   the arguments to the function. $ret_reg is the location where the return
#   value should be stored. $free_register_callback is a sub that will return
#   the name of a free register whenever it's called.
#
sub assemble_perl_function_call
{
    my ($class, $name, $args_regs, $ret_reg, $free_register_callback) = @_;

    my $code = '';
    my $args_reg = &$free_register_callback();    

    $code .= "$args_reg = new .ResizablePMCArray\n";
    for (my $i = 0; $i < @$args_regs; $i++) {
        $code .= "${args_reg}[$i] = $args_regs->[$i]\n";
    }
    
    my $nci_reg = &$free_register_callback();
    $code .= qq/$nci_reg = find_global "_core_embedded", "_call_perl"\n/;
    $code .= qq/$ret_reg = $nci_reg($args_reg, "$name")\n/;

    return $code;
}

sub emit_error
{
    my ($message) = @_;

    die "$message\n";
}

1;

