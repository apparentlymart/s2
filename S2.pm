#!/usr/bin/perl
#

package S2;

use strict;

## array indexes into $_ctx (which shows up in compiled S2 code)
use constant VTABLE => 0;
use constant STATICS => 1;
use constant PROPS => 2;
use constant SCRATCH => 3;  # embedder-defined use

my %layer;       # lid -> time()
my %layercomp;   # lid -> compiled time (when loaded from database)
my %layerinfo;   # lid -> key -> value
my %layerset;    # lid -> key -> value
my %layerprop;   # lid -> prop -> { type/key => "string"/val }
my %layerprops;  # lid -> arrayref of hashrefs
my %layerprophide; # lid -> prop -> 1
my %layerfunc;   # lid -> funcnum -> sub{}
my %layerclass;  # lid -> classname -> hashref
my %layerglobal; # lid -> signature -> hashref
my %funcnum;     # funcID -> funcnum
my $funcnummax;  # maxnum in use already by funcnum, above.

my $output_sub;

sub get_layer_all
{
    my $lid = shift;
    return undef unless $layer{$lid};
    return {
        'layer' => $layer{$lid},
        'info' => $layerinfo{$lid},
        'set' => $layerset{$lid},
        'prop' => $layerprop{$lid},
        'class' => $layerclass{$lid},
        'global' => $layerglobal{$lid},
    };
}

sub pout
{
    if ($output_sub) {
	$output_sub->(@_);
    } else {
	print @_;
    }
}

sub get_property_value
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

        ## FIXME: load the layer if not loaded, using registered
        ## loader sub.

	## setup the property values
	foreach my $p (keys %{$layerset{$lid}}) {
            my $v = $layerset{$lid}->{$p};

            # this was the old format, but only used for Color constructors,
            # so we can change it to the new format:
            $v = S2::Builtin::Color__Color($v->[0])
                if (ref $v eq "ARRAY" && scalar(@$v) == 2 && 
                    ref $v->[1] eq "CODE");

	    $ctx->[PROPS]->{$p} = $v;
	}
    }

    return $ctx;
}

sub register_class
{
    my ($lid, $classname, $info) = @_;
    $layerclass{$lid}->{$classname} = $info;
}

sub register_layer
{
    my ($lid) = @_;
    unregister_layer($lid) if $layer{$lid};
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
    delete $layerprophide{$lid};
    delete $layerfunc{$lid};
    delete $layerclass{$lid};
    delete $layerglobal{$lid};
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
    my $where = join(' OR ', @to_load);
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

sub register_property_use
{
    my ($lid, $propname) = @_;
    push @{$layerprops{$lid}}, $propname;
}

sub register_property_hide
{
    my ($lid, $propname) = @_;
    $layerprophide{$lid}->{$propname} = 1;
}

sub is_property_hidden
{
    my ($lids, $propname) = @_;
    foreach (@$lids) {
        return 1 if $layerprophide{$_}->{$propname};
    }
    return 0;
}

sub get_property
{
    my ($lid, $propname) = @_;
    return $layerprop{$lid}->{$propname};
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
    return $v;
}

# the whole point here is just to get the docstring.
sub register_global_function
{
    my ($lid, $func, $rtype, $docstring) = @_;

    # need to make the signature:  foo(int a, int b) -> foo(int,int)
    return unless 
        $func =~ /^(.+?\()(.*)\)$/;
    my ($signature, @args) = ($1, split(/\s*\,\s*/, $2));
    foreach (@args) { s/\s+\w+$//; } # strip names
    $signature .= join(",", @args) . ")";
    $layerglobal{$lid}->{$signature} = {
        'returntype' => $rtype,
        'docstring' => $docstring,
        'args' => $func,
    };    
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

sub function_exists
{
    my ($ctx, $func) = @_;
    my $fnum = get_func_num($func);
    my $code = $ctx->[VTABLE]->{$fnum};
    return 1 if ref $code eq "CODE";
    return 0;
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
    my ($type, $inst, $func, $s2lid, $s2line, $is_super) = @_;
    if (ref $inst ne "HASH" || $inst->{'_isnull'}) {
        die "Method called on null $type object at layer \#$s2lid, line $s2line.\n";
    }
    $type = $inst->{'_type'} unless $is_super;
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

sub int__zeropad
{
    my ($ctx, $this, $digits) = @_;
    $digits += 0;
    sprintf("%0${digits}d", $this);
}

sub string__substr
{
    my ($ctx, $this, $start, $length) = @_;
    use utf8;
    return substr($this, $start, $length);
}

sub string__length
{
    use utf8;
    my ($ctx, $this) = @_;
    return length($this);
}

sub string__lower
{
    use utf8;
    my ($ctx, $this) = @_;
    return lc($this);
}

sub string__upper
{
    use utf8;
    my ($ctx, $this) = @_;
    return uc($this);
}

sub string__upperfirst
{
    use utf8;
    my ($ctx, $this) = @_;
    return ucfirst($this);
}

sub string__startswith
{
    use utf8;
    my ($ctx, $this, $str) = @_;
    return $this =~ /^\Q$str\E/;
}

sub string__endswith
{
    use utf8;
    my ($ctx, $this, $str) = @_;
    return $this =~ /\Q$str\E$/;
}

sub string__contains
{
    use utf8;
    my ($ctx, $this, $str) = @_;
    return $this =~ /\Q$str\E/;
}

sub string__repeat
{
    use utf8;
    my ($ctx, $this, $num) = @_;
    $num += 0;
    my $size = length($this) * $num;
    return "[too large]" if $size > 5000;
    return $this x $num;
}


sub Color__Color
{
    my ($s) = @_;
    my $this = { '_type' => 'Color' };
    $this->{'r'} = hex(substr($s, 1, 2));
    $this->{'g'} = hex(substr($s, 3, 2));
    $this->{'b'} = hex(substr($s, 5, 2));
    Color__make_string($this);
    return $this;
}


sub Color__make_string
{
    my ($this) = @_;
    $this->{'as_string'} = sprintf("\#%02x%02x%02x",
				  $this->{'r'},
				  $this->{'g'},
				  $this->{'b'});
}

sub Color__red {
    my ($ctx, $this, $v) = @_;
    if ($v) { $this->{'r'} = $v; Color__make_string($this); }
    $this->{'r'};
}

sub Color__green {
    my ($ctx, $this, $v) = @_;
    if ($v) { $this->{'g'} = $v; Color__make_string($this); }
    $this->{'g'};
}

sub Color__blue {
    my ($ctx, $this, $v) = @_;
    if ($v) { $this->{'b'} = $v; Color__make_string($this); }
    $this->{'b'};
}

sub Color__inverse {
    my ($ctx, $this) = @_;
    my $new = {
        '_type' => 'Color',
        'r' => 255 - $this->{'r'},
        'g' => 255 - $this->{'g'},
        'b' => 255 - $this->{'b'},
    };
    Color__make_string($new);
    return $new;
}

sub Color__average {
    my ($ctx, $this, $other) = @_;
    my $new = {
        '_type' => 'Color',
        'r' => int(($this->{'r'} + $other->{'r'}) / 2),
        'g' => int(($this->{'g'} + $other->{'g'}) / 2),
        'b' => int(($this->{'b'} + $other->{'b'}) / 2),
    };
    Color__make_string($new);
    return $new;


1;

