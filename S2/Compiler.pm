#!/usr/bin/perl
#

package S2::Compiler;

use strict;
use S2::Tokenizer;
use S2::Checker;
use S2::Layer;
use S2::Util;
use S2::BackendPerl;
use S2::BackendHTML;
use S2::OutputScalar;

sub new # (fh) class method
{
    my ($class, $opts) = @_;
    $opts->{'checker'} ||= new S2::Checker;
    bless $opts, $class;
}

sub compile_source {
    my ($this, $opts) = @_;
    my $ref = ref $opts->{'source'} ? $opts->{'source'} : \$opts->{'source'};
    my $toker = S2::Tokenizer->new($ref);
    my $s2l = S2::Layer->new($toker, $opts->{'type'});
    my $o = new S2::OutputScalar($opts->{'output'});
    my $be;
    if ($opts->{'format'} eq "html") {
        $be = new S2::BackendHTML($s2l);
    } else {
        $this->{'checker'}->checkLayer($s2l);
        $be = new S2::BackendPerl($s2l, $opts->{'layerid'}, $opts->{'untrusted'});
        if ($opts->{'builtinPackage'}) {
            $be->setBuiltinPackage($opts->{'builtinPackage'});
        }
    }
    $be->output($o);
    return 1;
}


1;
