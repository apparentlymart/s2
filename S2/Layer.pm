#!/usr/bin/perl
#

package S2::Layer;

use S2::NodeUnnecessary;

sub new
{
    my ($class, $toker, $type) = @_;
    my $this = {
        'type' => $type,
        'declaredType' => undef,
        'nodes' => [],
        'layerinfo' => {},
    };

    my $nodes = $this->{'nodes'};

    while (my $t = $toker->peek()) {

        if (S2::NodeUnnecessary->canStart($toker)) {
            push @$nodes, S2::NodeUnnecessary->parse($toker);
            next;
        }

        # ...

        die "Unknown token encountered while parsing layer: " .
            $t->toString() . "\n";
    }

    bless $this, $class;
}

sub setLayerInfo {
    my ($this, $key, $val) = @_;
    $this->{'layerinfo'}->{$key} = $val;
}

sub getLayerInfo {
    my ($this, $key) = @_;
    $this->{'layerinfo'}->{$key};
}




1;
