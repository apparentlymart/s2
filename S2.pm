#!/usr/bin/perl
#

package S2;

use strict;
use vars qw($pout $pout_s);  # public interface:  sub refs to print and print safely

$pout = sub { print @_; };
$pout_s = sub { print @_; };

## array indexes into $_ctx (which shows up in compiled S2 code)
use constant VTABLE => 0;
use constant STATICS => 1;
use constant PROPS => 2;
use constant SCRATCH => 3;  # embedder-defined use
use constant LAYERLIST => 4;  # arrayref of layerids which made the context

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
my %layerpropgroups; # lid -> [ group_ident* ]
my %layerpropgroupname; # lid -> group_ident -> text_name
my %layerpropgroupprops; # lid -> group_ident -> [ prop_ident* ]
my %funcnum;     # funcID -> funcnum
my $funcnummax;  # maxnum in use already by funcnum, above.

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
        'propgroupname' => $layerpropgroupname{$lid},
        'propgroups' => $layerpropgroups{$lid},
        'propgroupprops' => $layerpropgroupprops{$lid},
    };
}

# compatibility functions
sub pout   { $pout->(@_);   }
sub pout_s { $pout_s->(@_); }

sub get_property_value
{
    my ($ctx, $k) = @_;
    return $ctx->[PROPS]->{$k};
}

sub get_lang_code
{
    return get_property_value($_[0], 'lang_current');
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

    $ctx->[LAYERLIST] = [ @lids ];
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
    delete $layerpropgroups{$lid};
    delete $layerpropgroupprops{$lid};
    delete $layerpropgroupname{$lid};
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

sub layer_loaded 
{
    my ($id) = @_;
    return $layercomp{$id};
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

sub register_propgroup_name
{
    my ($lid, $gname, $name) = @_;
    $layerpropgroupname{$lid}->{$gname} = $name;
}

sub register_propgroup_props
{
    my ($lid, $gname, $list) = @_;
    $layerpropgroupprops{$lid}->{$gname} = $list;
    push @{$layerpropgroups{$lid}}, $gname;
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

sub get_property_groups
{
    my $lid = shift;
    return @{$layerpropgroups{$lid} || []};
}

sub get_property_group_props
{
    my ($lid, $group) = @_;
    return () unless $layerpropgroupprops{$lid};
    return @{$layerpropgroupprops{$lid}->{$group} || []};
}

sub get_property_group_name
{
    my ($lid, $group) = @_;
    return unless $layerpropgroupname{$lid};
    return $layerpropgroupname{$lid}->{$group};
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
# attrs is a comma-delimited list of attributes
sub register_global_function
{
    my ($lid, $func, $rtype, $docstring, $attrs) = @_;

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
        'attrs' => $attrs,
    };    
}

sub register_function
{
    my ($lid, $names, $code) = @_;

    # run the code to get the sub back with its closure data filled.
    my $closure = $code->();

    # now, remember that closure.
    foreach my $fi (@$names) {
	my $num = get_func_num($fi);
	$layerfunc{$lid}->{$num} = $closure;
    }
}

sub set_output
{
    $pout = shift;
}

sub set_output_safe
{
    $pout_s = shift;
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
    run_function($ctx, $entry, @args);
    return 1;
}

sub run_function
{
    my ($ctx, $entry, @args) = @_;
    my $fnum = get_func_num($entry);
    my $code = $ctx->[VTABLE]->{$fnum};
    unless (ref $code eq "CODE") {
        die "S2::run_code: Undefined function $entry ($fnum $code)\n";
    }
    my $val;
    eval {
        local $SIG{__DIE__} = undef;
        local $SIG{ALRM} = sub { die "Style code didn't finish running in a timely fashion.  ".
                                     "Possible causes: <ul><li>Infinite loop in style or layer</li>\n".
                                     "<li>Database busy</li></ul>\n" };
        alarm 4;
        $val = $code->($ctx, @args);
        alarm 0;
    };
    if ($@) {
        die "Died in S2::run_code running $entry: $@\n";
    }
    return $val;
}

sub get_func_num
{
    my $name = shift;
    return $funcnum{$name} if exists $funcnum{$name};
    return $funcnum{$name} = ++$funcnummax;
}

sub get_object_func_num
{
    my ($type, $inst, $func, $s2lid, $s2line, $is_super) = @_;
    if (ref $inst ne "HASH" || $inst->{'_isnull'}) {
        die "Method called on null $type object at layer \#$s2lid, line $s2line.\n";
    }
    $type = $inst->{'_type'} unless $is_super;
    my $fn = get_func_num("${type}::$func");
    #Apache->request->log_error("get_object_func_num(${type}::$func) = $fn");
    return $fn;
}

# Called by NodeForeachStmt
sub get_characters 
{
    my $string = shift;
    use utf8;
    return split(//,$string);
}

sub check_defined {
    my $obj = shift;
    return ref $obj eq "HASH" && ! $obj->{'_isnull'};
}

sub check_elements {
    my $obj = shift;
    if (ref $obj eq "ARRAY") {
        return @$obj ? 1 : 0;
    } elsif (ref $obj eq "HASH") {
        return %$obj ? 1 : 0;
    }
    return 0;
}

sub interpolate_object {
    my ($ctx, $cname, $obj, $method) = @_;
    return "" unless ref $obj eq "HASH" && ! $obj->{'_isnull'};
    return $ctx->[VTABLE]->{get_object_func_num($cname,$obj,$method)}->($ctx, $obj);
}

sub notags {
    my $a = shift;
    $a =~ s/</&lt;/g;
    $a =~ s/>/&gt;/g;
    return $a;
}

package S2::Builtin;

# generic S2 has no built-in functionality

1;

