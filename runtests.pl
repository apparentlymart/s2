#!/usr/bin/perl
#

use strict;
use Getopt::Long;
use S2;

my $opt_output;
my $opt_warn;
GetOptions("output" => \$opt_output,
	   "warnings" => \$opt_warn);

my $runwhat = shift;

my $TESTDIR = "tests";

my @files;
if ($runwhat) { 
    $runwhat =~ s!^.*\/!!;
    @files = ($runwhat);
} else {
    opendir(D, $TESTDIR) || die "Can't open 'tests' directory.\n";
    while (my $f = readdir(D)) {
	if (-f "$TESTDIR/$f" && $f =~ /\.s2$/) {
	    push @files, $f;
	}
    }
    closedir(D);
    @files = sort @files;
}

my $jtime = (stat("s2compile.jar"))[9];
my @errors;

foreach my $f (@files)
{
    print STDERR "Testing: $f\n";
    my $pfile = "$TESTDIR/$f.pl";
    my $stime = (stat("$TESTDIR/$f"))[9];
    my $ptime = (stat($pfile))[9];

    my $build = 0;
    if ($opt_warn) { $build = 1; }
    unless ($ptime > $stime && $ptime > $jtime) {
	if ($stime > $ptime || $jtime > $ptime) {
	    $build = 1;
	}
    }

    if ($build) {
	my $no_warn = "2> /dev/null ";
	if ($opt_warn) { $no_warn = ""; }
	my $cmd = "./s2compile -output perl -layerid 1 -layertype core $TESTDIR/$f $no_warn> $pfile";
	print STDERR "# $cmd\n";
	my $ret = system($cmd);
        if ($ret) { die "Failed to run!\n"; } 
	if (-z $pfile) {
	    push @errors, [ $f, "Failed to compiled." ];
	}
    }

    my $output = "";
    S2::set_output(sub { $output .= $_[0]; });
    S2::unregister_layer(1);
    unless (S2::load_layer_file($pfile)) {
        die $@;
    }
    my $ctx = S2::make_context([ 1 ]);
    eval {
        S2::run_code($ctx, "main()");
    };
    if ($@) {
        $output .= "ERROR: $@";
    }

    if ($opt_output) {
	print $output;
    }

    my $ofile = "$TESTDIR/$f.out";
    if (-e $ofile) {
	open (O, $ofile);
	my $goodout = join('',<O>);
	close O;
	if (trim($output) ne trim($goodout)) {
	    push @errors, [ $f, "Output differs." ];
	}
    } else {
	push @errors, [ $f, "No expected output file." ];
    }
}

unless (@errors) {
    print STDERR "\nAll tests passed.\n\n";
    exit 0;
}

print STDERR "\nERRORS:\n======\n";
foreach my $e (@errors)
{
    printf STDERR "%-30s %s\n", $e->[0], $e->[1];
}
print STDERR "\n";
exit 1;

sub trim
{
    my $a = shift;
    $a =~ s/^\s+//;
    $a =~ s/\s+$//;
    return $a;
}
