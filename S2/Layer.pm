#!/usr/bin/perl
#

package S2::Layer;

use S2::NodeUnnecessary;
use S2::NodeLayerInfo;
use S2::NodeProperty;
use S2::NodeSet;

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

        if (S2::NodeLayerInfo->canStart($toker)) {
            my $nli = S2::NodeLayerInfo->parse($toker);
            push @$nodes, $nli;
            if ($nli->getKey() eq "type") {
                $this->{'declaredType'} = $nli->getValue();
            }
            next;
        }

        if (S2::NodeProperty->canStart($toker)) {
            push @$nodes, S2::NodeProperty->parse($toker);
            next;
        }

        if (S2::NodeSet->canStart($toker)) {
            push @$nodes, S2::NodeSet->parse($toker);
            next;
        }
=pod

	    if (NodeFunction.canStart(toker)) {
		nodes.add(NodeFunction.parse(toker, false));
		continue;
	    }
		
	    if (NodeClass.canStart(toker)) {
		nodes.add(NodeClass.parse(toker));
		continue;
	    }
=cut

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

sub getLayerInfoKeys {
    my ($this) = @_;
    return [ keys %{$this->{'layerinfo'}} ];
}

sub getType {
    shift->{'type'};
}

sub getDeclaredType {
    shift->{'declaredType'};
}

sub setType {
    shift->{'type'} = shift;
}

sub toString {
    shift->{'type'};
}

sub getNodes {
    return shift->{'nodes'};
}

sub isCoreOrLayout {
    my $this = shift;
    return $this->{'type'} eq "core" ||
        $this->{'type'} eq "layout";
}

1;
