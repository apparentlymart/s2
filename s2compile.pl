#!/usr/bin/perl
#

use Data::Dumper;
use strict;
use FindBin;
use lib "$FindBin::Bin";
use IO::File;
use Getopt::Long;
use S2::Tokenizer;
use S2::Checker;
use S2::Layer;
use S2::Util;
use S2::OutputConsole;
use S2::BackendPerl;

my $output;
my $layerid;
my $layertype;
my ($opt_core, $opt_layout);

exit usage() unless
    GetOptions("output=s" => \$output,
               "layerid=i" => \$layerid,
               "layertype=s" => \$layertype,
               "core=s" => \$opt_core,
               "layout=s" => \$opt_layout,
               );

exit usage() unless @ARGV == 1;

my $filename = shift @ARGV;

unless ($output) {
    print STDERR "No output format specified\n";
    exit 1;
}

if ($output eq "tokens") {
    my $toker = S2::Tokenizer->new(getFileHandle($filename));
    while (my $tok = $toker->getToken()) {
        print $tok->toString(), "\n";
    }
    print "end.\n";
    exit 0;
}


my $ck;
my $layerMain;

# TODO: respect cmdline option to pre-load serialized checker to
#       avoid having to make one by reparsing source of core[+layout]

if ($output eq "html" || $output eq "s2") {
    $ck = undef;
} else {
    $ck = new S2::Checker;
    if (! defined $layertype) {
        die "Unspecified layertype.\n";
    } elsif ($layertype eq "core") {
        # nothing.
    } elsif ($layertype eq "i18nc" || $layertype eq "layout") {
        makeLayer($opt_core, "core", $ck);
    } elsif ($layertype eq "theme" || $layertype eq "i18n" || $layertype eq "user") {
        makeLayer($opt_core, "core", $ck);
        makeLayer($opt_layout, "layout", $ck);
    } else {
        die "Invalid layertype.\n";
    }

    $layerMain = makeLayer($filename, $layertype, $ck);
        
    $S2::Compile::topLayerName = $layerMain->getLayerInfo("name");
    $S2::Compile::topLayerType = $layerMain->{'type'};

    my $o = new S2::OutputConsole();
    my $be = undef;
        
    if ($output eq "html") {
        $be = new S2::BackendHTML($layerMain);
    }
        
    if ($output eq "s2") {
        $be = new S2::BackendS2($layerMain);
    }
        
    if ($output eq "perl") {
        die "No layerid specified" unless $layerid;
        $be = new S2::BackendPerl($layerMain, $layerid);
    }

    unless ($be) {
        die("No backend found for '$output'\n'");
    }

    $be->output($o);
    $o->flush();
    exit 0;
}

###################### functions

sub getFileHandle {
    my $filename = shift;
    my $fh;

    if ($filename eq "-") {
        $fh = new IO::Handle;
        return $fh if $fh->fdopen(fileno(STDIN),"r");
        die "Couldn't open STDIN?\n";
    }
        $fh = new IO::File $filename, "r";
    return $fh if defined $fh;
    die "Can't open file: $filename\n";
}

sub makeLayer {
    my ($filename, $type, $ck) = @_;
    unless ($filename) {
        die "Undefined filename for '$type' layer.\n";
    }
    
    my $toker = S2::Tokenizer->new(getFileHandle($filename));
    my $s2l = S2::Layer->new($toker, $type);
    # now check the layer, since it must have parsed fine (otherwise
    # the Layer constructor would have thrown an exception
    $ck->checkLayer($s2l) if $ck;
    return $s2l;
}

sub usage {
    print STDERR <<'USAGE';
Usage: 
   s2compile [opts]* <file>
Options:
   --output <format>     One of: perl, html, s2, tokens
   --layerid <int>       For perl output format only
   --layertype <type>    One of: core, i18nc, layout, theme, i18n, user
   --core <filename>     Core S2 file, if layertype after core
   --layout <filename>   Layout S2 file, if compiling layer after layout

Any file args can be '-' to read from STDIN, ending with ^D
USAGE

   return 1;
}
