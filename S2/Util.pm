#!/usr/bin/perl
#

package S2;

sub error {
    my ($where, $msg) = @_;
    if (ref $where && ($where->isa('S2::Token') ||
                       $where->isa('S2::Node'))) {
        $where = $where->getFilePos();
    }
    if (ref $where eq "S2::FilePos") {
        $where = $where->locationString;
    }

    my $i = 0;
    print STDERR "$where: $msg\n";
    while (my ($p, $f, $l) = caller($i++)) {
        print STDERR "  $p, $f, $l\n";
    }
    exit 1;
}


1;
