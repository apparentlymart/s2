#!/usr/bin/perl
#

package S2::BackendPerl;

use strict;
use S2::Indenter;

sub new {
    my ($class, $l, $layerID) = @_;
    my $this = {
        'layer' => $l,
        'layerID' => $layerID,
    };
    bless $this, $class;
}

sub getLayerID { shift->{'layerID'}; }
sub getLayerIDString { shift->{'layerID'}; }

sub output {
    my ($this, $o) = @_;
    my $io = new S2::Indenter $o, 4;

    $io->writeln("#!/usr/bin/perl");
    $io->writeln("# auto-generated Perl code from input S2 code"); 
    $io->writeln("package S2;");
    $io->writeln("use strict;");
    $io->writeln("use constant VTABLE => 0;");
    $io->writeln("use constant STATIC => 1;");
    $io->writeln("use constant PROPS => 2;");
    $io->writeln("register_layer($this->{'layerID'});");
    my $nodes = $this->{'layer'}->getNodes();
    foreach my $n (@$nodes) {
        $n->asPerl($this, $io);
    }
    $io->writeln("1;");
    $io->writeln("# end.");
}

sub quoteString {
    shift if ref $_[0];
    my $s = shift;
    return "\"" . quoteStringInner($s) . "\"";
}

sub quoteStringInner {
    my $s = shift;
    $s =~ s/([\\\$\"\@])/\\$1/g;
    $s =~ s/\n/\\n/g;
    return $s;
}


1;
