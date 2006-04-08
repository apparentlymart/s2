
=head1 NAME

S2::Runtime::OO - Object-oriented S2 runtime

=head1 SYNOPSIS

    use S2::Runtime::OO;
    
    my $s2 = new S2::Runtime::OO;
    
    my $core = $s2->layer_from_file('core.pl');
    my $layout = $s2->layer_from_file('layout.pl');
    
    my $ctx = $s2->make_context($core, $layout);
    $ctx->set_print(sub { print @_; });

    my $page = {
        '_type' => 'Page',
        # ...
    };

    $ctx->run_function("Page::print()", $page);

=cut

package S2::Runtime::OO;

use S2::Runtime::OO::Context;
use S2::Runtime::OO::Layer;

sub new {
    return bless {}, shift;
}

sub layer_from_string {
    return eval(${$_[1]});
}

sub layer_from_file {
    return require($_[1]);
}

sub make_context {
    my ($self, @layers) = @_;
    
    @layers = @{$layers[0]} if (ref $layers[0] eq 'ARRAY');
    
    return new S2::Runtime::OO::Context(@layers);
}

1;
