#!/usr/bin/perl
#

package S2;

use strict;

## array indexes into $_ctx (which shows up in compiled S2 code)
use constant VTABLE => 0;
use constant STATICS => 1;
use constant PROPS => 2;

my %layer;       # lid -> time()
my %layercomp;   # lid -> compiled time (when loaded from database)
my %layerinfo;   # lid -> key -> value
my %layerset;    # lid -> key -> value
my %layerprop;   # lid -> prop -> { type/key => "string"/val }
my %layerprops;  # lid -> arrayref of hashrefs
my %layerfunc;   # lid -> funcnum -> sub{}
my %funcnum;     # funcID -> funcnum
my $funcnummax;  # maxnum in use already by funcnum, above.

my $output_sub;

sub pout
{
    if ($output_sub) {
	$output_sub->(@_);
    } else {
	print @_;
    }
}

sub get_property
{
    my ($ctx, $k) = @_;
    return $ctx->[PROPS]->{$k};
}

sub make_context
{
    my (@lids) = @_;
    if (ref $lids[0] eq "ARRAY") { @lids = @{$lids[0]}; } # 1st arg can be array ref
    my $ctx = [];
    undef $@;

    ## load all the layers & make the vtable
    foreach my $lid (0, @lids)
    {
	## build the vtable
	foreach my $fn (keys %{$layerfunc{$lid}}) {
	    $ctx->[VTABLE]->{$fn} = $layerfunc{$lid}->{$fn};
	}

	## ignore further stuff for layer IDs of 0
	next unless $lid;

	## try to load the layer
	unless (load_layer($lid)) {
	    $@ = "Error loading layer \#$lid: $@";
	    return undef;
	}

	## setup the property values
	foreach my $p (keys %{$layerset{$lid}}) {
	    my $v = $layerset{$lid}->{$p};
	    if (ref $v eq "ARRAY") {
		# then this property is assigning to an object,
		# which means the property's object type must
		# have a constructor which takes a string.  the
		# second array element in this property
		# is a sub which will return the real value.

		$v = $v->[1]->($ctx);
	    }
	    $ctx->[PROPS]->{$p} = $v;
	}
    }

    return $ctx;
}

sub register_layer
{
    my ($lid) = @_;
    $layer{$lid} = time();
}

sub unregister_layer
{
    my ($lid) = @_;
    delete $layer{$lid};
    delete $layercomp{$lid};
    delete $layerinfo{$lid};
    delete $layerset{$lid};
    delete $layerprop{$lid};
    delete $layerprops{$lid};
    delete $layerfunc{$lid};
}

sub load_layer
{
    my ($lid) = @_;

    # don't load it if it's already loaded.
    if ($layer{$lid}) {
	return 1;
    }

    undef $@;
    my $s2file = "layers/$lid.s2";
    my $cfile = "layers/$lid.pl";
    unless (-e $s2file) {
	$@ = "failed loading";
	return 0;
    }
    if ((stat($s2file))[9] > (stat($cfile))[9])
    {
	my $cmd = "./s2compile perl $lid $s2file > $cfile";
	print "# $cmd\n";
	system($cmd) and die "Failed to run!\n";
    }
    return load_layer_file($cfile);
}

sub load_layers_from_db
{
    my ($db, @layers) = @_;
    my $maxtime = 0;
    my @to_load;
    foreach my $lid (@layers) {
        $lid += 0;
        if (exists $layer{$lid}) {
            $maxtime = $layercomp{$lid} if $layercomp{$lid} > $maxtime;
            push @to_load, "(s2lid=$lid AND comptime>$layercomp{$lid})";
        } else {
            push @to_load, "s2lid=$lid";
        }
    }
    return $maxtime unless @to_load;
    my $where = join(' OR ', @layers);
    my $sth = $db->prepare("SELECT s2lid, compdata, comptime FROM s2compiled WHERE $where");
    $sth->execute;
    while (my ($id, $comp, $comptime) = $sth->fetchrow_array) {
        eval $comp;
        if ($@) {
            my $err = $@;
            unregister_layer($id);
            die "Layer \#$id: $err";
        }
        $layercomp{$id} = $comptime;
        $maxtime = $comptime if $comptime > $maxtime;
    }
    return $maxtime;
}

sub load_layer_file
{
    my ($file) = @_;
    undef $@;
    unless (eval "require \"$file\";") {
	$@ = "failed loading: $@";
	return 0;
    }
    return 1;
}

sub set_layer_info
{
    my ($lid, $key, $val) = @_;
    $layerinfo{$lid}->{$key} = $val;
}

sub get_layer_info
{
    my ($lid, $key) = @_;
    return undef unless $layerinfo{$lid};
    return $key ? $layerinfo{$lid}->{$key} : %{$layerinfo{$lid}};
}

sub register_property
{
    my ($lid, $propname, $props) = @_;
    $props->{'name'} = $propname;
    $layerprop{$lid}->{$propname} = $props;
    push @{$layerprops{$lid}}, $props;
}

sub get_properties
{
    my ($lid) = @_;
    return () unless $layerprops{$lid};
    return @{$layerprops{$lid}};
}

sub register_set
{
    my ($lid, $propname, $val) = @_;
    $layerset{$lid}->{$propname} = $val;
}

sub get_set
{
    my ($lid, $propname) = @_;
    my $v = $layerset{$lid}->{$propname};
    return undef unless defined $v;
    return ref $v ? $v->[0] : $v;  # return just value, not coderef of ctor
}

sub register_function
{
    my ($lid, $names, $code) = @_;

    # register the function names first, before we eval the code 
    # to get the closure, because the subref might be recursive,
    # in which case it'll die if it needs to call itself and it
    # doesn't think it exists yet.
    foreach my $fi (@$names) { register_func_num($fi); }

    # run the code to get the sub back with its closure data filled.
    my $closure = $code->();

    # now, remember that closure.
    foreach my $fi (@$names) {
	my $num = register_func_num($fi);
	$layerfunc{$lid}->{$num} = $closure;
    }
}

sub set_output
{
    my $code = shift;
    $output_sub = $code;
}

sub run_code
{
    my ($ctx, $entry, @args) = @_;
    my $fnum = get_func_num($entry);
    my $code = $ctx->[VTABLE]->{$fnum};
    unless (ref $code eq "CODE") {
        die "S2::run_code: Undefined function $entry";
    }
    eval {
        $code->($ctx, @args);
    };
    if ($@) {
        die "Died in S2::run_code running $entry: $@\n";
    }
    return 1;
}

sub register_func_num
{
    my $name = shift;
    return $funcnum{$name} if exists $funcnum{$name};
    return $funcnum{$name} = ++$funcnummax;
}

sub get_func_num
{
    my $name = shift;
    my $num = $funcnum{$name};
    return $num if $num;

    die "S2::get_func_num: Undefined function $name\n";
}

sub get_object_func_num
{
    my ($type, $inst, $func, $s2lid, $s2line) = @_;
    if (ref $inst ne "HASH" || $inst->{'_isnull'}) {
        die "Method called on null $type object at layer \#$s2lid, line $s2line.\n";
    }
    $type = $inst->{'_type'};
    return get_func_num("${type}::$func");
}

# Called by NodeForeachStmt
sub get_characters 
{
    my $string = shift;
    use utf8;
    return split(//,$string);
}

package S2::Builtin;

sub string__substr
{
    # FIXME: want to use character semantics here, not bytes (the default)
    # just "use utf8" ?
    my ($ctx, $this, $start, $length) = @_;
    return substr($this, $start, $length);
}

sub Color__Color
{
    my ($ctx, $s) = @_;
    my $this = { '_type' => 'Color' };
    $this->{'_r'} = hex(substr($s, 1, 2));
    $this->{'_g'} = hex(substr($s, 3, 2));
    $this->{'_b'} = hex(substr($s, 5, 2));
    Color__make_string($ctx, $this);
    return $this;
}


sub Color__make_string
{
    my ($ctx, $this) = @_;
    $this->{'as_string'} = sprintf("\#%02x%02x%02x",
				  $this->{'_r'},
				  $this->{'_g'},
				  $this->{'_b'});
}

sub Color__red {
    my ($ctx, $this, $v) = @_;
    if ($v) { $this->{'_r'} = $v; Color__make_string($ctx, $this); }
    $this->{'_r'};
}

sub Color__green {
    my ($ctx, $this, $v) = @_;
    if ($v) { $this->{'_g'} = $v; Color__make_string($ctx, $this); }
    $this->{'_g'};
}

sub Color__blue {
    my ($ctx, $this, $v) = @_;
    if ($v) { $this->{'_b'} = $v; Color__make_string($ctx, $this); }
    $this->{'_b'};
}


1;

