package Image::CairoSVG;
use warnings;
use strict;
use utf8;

our $VERSION = '0.14';

# Core modules
use Carp qw/carp croak/;
use ExtUtils::ParseXS::Utilities 'trim_whitespace';
use Math::Trig qw!acos pi rad2deg deg2rad!;
use Scalar::Util 'looks_like_number';

# Installed modules
use XML::Parser;
use Cairo;
use Graphics::ColorNames::WWW;
use Image::SVG::Path qw/extract_path_info create_path_string/;

our $default_surface_type = 'argb32';
our $default_surface_size = 100;
our @defaultrgb = (0, 0, 0);

sub new
{
    my ($class, %options) = @_;

    my $self = bless {};

    my $context = $options{context};
    my $surface = $options{surface};
    my $verbose = $options{verbose};

    delete $options{context};
    delete $options{surface};
    delete $options{verbose};

    for my $k (keys %options) {
	carp "Unknown option $k";
    }

    if ($verbose) {
	debugmsg ("Debugging messages switched on");
	$self->{verbose} = 1;
    }

    if ($context) {
	$self->{cr} = $context;
	if ($surface) {
	    carp "Value of surface ignored: specify either cr or surface";
	}
	if ($self->{verbose}) {
	    debugmsg ("Using user-supplied context $self->{cr}");
	}
    }
    elsif ($surface) {
	$self->{surface} = $surface;
	$self->make_cr ();
	if ($self->{verbose}) {
	    debugmsg ("Using user-supplied surface $self->{surface}");
	}
    }
    return $self;
}

sub make_cr
{
    my ($self) = @_;
    if (! $self->{surface}) {
	die "BUG: No surface";
    }
    $self->{cr} = Cairo::Context->create ($self->{surface});
    if (! $self->{cr}) {
	# We won't be able to do very much without a context.
	croak "Cairo::Context->create failed";
    }
}

sub render
{
    my ($self, $file) = @_;
    my $p = XML::Parser->new (
	Handlers => {
	    Start => sub {
		handle_start ($self, @_);
	    },
	    End => sub {
		handle_end ($self, @_);
	    },
	},
    );
    if ($file =~ /<.*>/) {
	if ($self->{verbose}) {
	    debugmsg ("Input looks like a scalar");
	}
	# parse from scalar
	$p->parse ($file);
    }
    elsif (! -f $file) {
	croak "No such file '$file'";
    }
    else {
	$self->{file} = $file;
	if ($self->{verbose}) {
	    debugmsg ("Input looks like a file");
	}
	$p->parsefile ($file);
    }
    return $self->{surface};
}

sub handle_end
{
    my ($self, $parser, $tag) = @_;
    my $element = pop @{$self->{elements}};
    my $attr = $element->{attr};
    $self->do_fill_stroke ($attr);
}

# <svg> tag seen

sub svg
{
    my ($self, %attr) = @_;
    my $width;
    my $height;
    if ($attr{width}) {
	$width = $attr{width};
	$width = svg_units ($width);
    }
    if ($attr{height}) {
	$height = $attr{height};
	$height = svg_units ($height);
    }
    if ($attr{fill}) {
	$self->{fill} = $attr{fill};
    }
    if ($attr{stroke}) {
	$self->{stroke} = $attr{stroke};
    }


    # Use viewBox attribute

    if (! defined $width && ! defined $height) {
	my $viewBox = $attr{viewBox} || $attr{viewbox};
	if ($viewBox) {
	    (undef, undef, $width, $height) = split /\s+/, $viewBox;
	}
    }
    my $surface = $self->{surface};
    if (! $self->{cr} && ! $surface) {
	if ($self->{verbose}) {
	    debugmsg ("User did not supply surface or context");
	}
	if (! $width || ! $height) {
	    carp "Image width or height not found in $self->{file}";
	    $surface = Cairo::ImageSurface->create (
		$default_surface_type,
		$default_surface_size,
		$default_surface_size,
	    );
	}
	else {
	    if ($self->{verbose}) {
		debugmsg ("Creating new surface");
	    }
	    $surface = Cairo::ImageSurface->create (
		$default_surface_type,
		$width,
		$height,
	    );
	}
	$self->{surface} = $surface;
	$self->make_cr ();
    }
    $self->do_svg_attr (%attr);
}

# Start tag handler for the XML parser. This is private.

sub handle_start
{
    my ($self, $parser, $tag, %attr) = @_;

    my $parent = $self->{elements}[-1];
    if ($parent) {
	my $pattr = $parent->{attr};
	for my $key (qw!
	    fill
	    stroke
	    stroke-linecap
	    stroke-linejoin
	    stroke-width
	!) {
	    # So where were the spiders
	    # While the fly tried to break our balls
	    if ($pattr->{$key} && ! $attr{$key}) {
		$attr{$key} = $pattr->{$key};
	    }
	}
    }

    my $element = {
	tag => $tag,
	attr => \%attr,
    };
    push @{$self->{elements}}, $element;

    if ($tag eq 'svg') {
	$self->svg (%attr);
    }
    elsif ($tag eq 'path') {
	$self->path (%attr);
    }
    elsif ($tag eq 'polygon') {
	$self->polygon (%attr);
    }
    elsif ($tag eq 'line') {
	$self->line (%attr);
    }
    elsif ($tag eq 'circle') {
	$self->circle (%attr);
    }
    elsif ($tag eq 'ellipse') {
	$self->ellipse (%attr);
    }
    elsif ($tag eq 'rect') {
	$self->rect (%attr);
    }
    elsif ($tag eq 'title') {
	;
    }
    elsif ($tag eq 'g') {
	$self->g (%attr);
    }
    elsif ($tag eq 'polyline') {
	$self->polyline (%attr);
    }
    else {
	if ($self->{verbose}) {
	    # There are probably many of these since this module is
	    # not up to spec, so only complain if the user wants
	    # "verbose" messages.
	    carp "Unhandled SVG tag '$tag'";
	}
    }

    # http://www.princexml.com/doc/7.1/svg/
    # g, rect, circle, ellipse, line, path, text, tspan
    # Also "use" etc.
}

sub g
{
    my ($self, %attr) = @_;
    # Group element
}

sub rect
{
    my ($self, %attr) = @_;

    my $x = svg_units ($attr{x});
    my $y = svg_units ($attr{y});
    my $width = svg_units ($attr{width});
    my $height = svg_units ($attr{height});

    my $cr = $self->{cr};

    $cr->rectangle ($x, $y, $width, $height);

    $self->do_svg_attr (%attr);
}

sub ellipse
{
    my ($self, %attr) = @_;

    my $cx = svg_units ($attr{cx});
    my $cy = svg_units ($attr{cy});
    my $rx = svg_units ($attr{rx});
    my $ry = svg_units ($attr{ry});

    my $cr = $self->{cr};

    # http://cairographics.org/manual/cairo-Paths.html#cairo-arc

    $cr->save ();
    $cr->translate ($cx, $cy);
    $cr->scale ($rx, $ry);

    # Render it.

    $cr->arc (0, 0, 1, 0, 2*pi);

    $cr->restore ();

    $self->do_svg_attr (%attr);
}

sub circle
{
    my ($self, %attr) = @_;

    my $cx = svg_units ($attr{cx});
    my $cy = svg_units ($attr{cy});
    my $r = svg_units ($attr{r});

    my $cr = $self->{cr};

    # Render it.

    $cr->arc ($cx, $cy, $r, 0, 2*pi);

    $self->do_svg_attr (%attr);
}

sub split_points
{
    my ($points) = @_;
    my @points = split /,\s*|\s+/, $points;
    die "Bad points $points" if @points % 2 != 0;
    return @points;
}

sub polygon
{
    my ($self, %attr) = @_;
    my @points = split_points ($attr{points});

    my $cr = $self->{cr};

    # Render it.

    my $y = pop @points;
    my $x = pop @points;
    $cr->move_to ($x, $y);

    while (@points) {
	$y = pop @points;
	$x = pop @points;
	$cr->line_to ($x, $y);
    }
    $cr->close_path ();
    $self->do_svg_attr (%attr);
}

sub polyline
{
    my ($self, %attr) = @_;
    my @points = split_points ($attr{points});

    my $cr = $self->{cr};

    # Render it.

    my $y = pop @points;
    my $x = pop @points;
    $cr->move_to ($x, $y);

    while (@points) {
	$y = pop @points;
	$x = pop @points;
	$cr->line_to ($x, $y);
    }
    $self->do_svg_attr (%attr);
}

sub path
{
    my ($self, %attr) = @_;

    # Get and parse the "d" attribute from the path using
    # Image::SVG::Path.

    my $d = $attr{d};
    croak "No d in path" unless $d;
    my @path_info = extract_path_info ($d, {
	absolute => 1,
	no_shortcuts => 1,
    });

    # Cairo context.

    my $cr = $self->{cr};

    if (! $cr) {
	croak "No context in $self";
    }

    for my $element (@path_info) {

	my $key = $element->{svg_key};

	if ($key eq lc $key) {
	    # This is a bug, "extract_path_info" above should never
	    # return a lower-case key, which means a relative path.
	    die "Path parse conversion to absolute failed";
	}

	if ($key eq 'S') {
	    # This is a bug, "extract_path_info" above should never
	    # return a shortcut key, they should have been converted
	    # to C keys.
	    die "Path parse conversion to no shortcuts failed";
	}
	if ($key eq 'M') {
	    # Move to
	    $cr->new_sub_path ();
	    $cr->move_to (@{$element->{point}});
	}
	elsif ($key eq 'L') {
	    $cr->line_to (@{$element->{point}});
	}
	elsif ($key eq 'C') {
	    $cr->curve_to (
		@{$element->{control1}},
		@{$element->{control2}},
		@{$element->{end}},
	    );
	}
	elsif ($key eq 'Z') {
	    $cr->close_path ();
	}
	elsif ($key eq 'Q') {
	    # Cairo doesn't support quadratic bezier curves, so we use
	    # quadbez to draw them.
	    quadbez ($cr, $element->{control}, $element->{end});
	}
	elsif ($key eq 'V') {
	    # Vertical line, x remains constant, so use original x ($xo).
	    my ($xo, undef) = $cr->get_current_point ();
	    $cr->line_to ($xo, $element->{y});
	}
	elsif ($key eq 'H') {
	    # Horizontal line, y remains constant, so use original y ($yo).
	    my (undef, $yo) = $cr->get_current_point ();
	    $cr->line_to ($element->{x}, $yo);
	}
	elsif ($key eq 'A') {
	    $self->svg_arc ($element);
	}
	else {
	    carp "Unknown SVG path key '$key': ignoring";
	}
    }
    $self->do_svg_attr (%attr);
}

# This is a Perl translation of 
# https://www.w3.org/TR/SVG/implnote.html#ArcImplementationNotes

sub svg_arc
{
    my ($self, $element) = @_;
    my $cr = $self->{cr};
    # Radii
    my $rx = $element->{rx};
    my $ry = $element->{ry};
    # End points
    my $x2 = $element->{x};
    my $y2 = $element->{y};

    # rx=0 or ry=0 means straight line
    if ($rx == 0 || $ry == 0) {
	$self->msg ("Arc has a zero radius rx=$rx or ry=$ry, treating as straight line");
	$cr->line_to ($x2, $y2);
	return;
    }
    my $fa = $element->{large_arc_flag};
    my $fs = $element->{sweep_flag};
    if ($fa != 0 && $fa != 1) {
	croak "large-arc-flag must be either 0 or 1";
    }
    if ($fs != 0 && $fs != 1) {
	croak "sweep-flag must be either 0 or 1";
    }
    $self->msg ("A: inputs: large-arc-flag: $fa, sweep-flag: $fs");
    # Start points
    my ($x1, $y1) = $cr->get_current_point ();
    $self->msg ("A: inputs: arc start: ($x1, $y1)");
    $self->msg ("A: inputs: arc end: ($x2, $y2)");
    $self->msg ("A: inputs: radii: ($rx, $ry)");
    my $phi = deg2rad ($element->{x_axis_rotation});
    $self->msg ("A: inputs: φ = $phi radians");
    my ($xd, $yd) = (($x1-$x2)/2, ($y1-$y2)/2);
    #    $self->msg ("Midpoint of vector from end to start: ($xd, $yd)");
    my $s = sin $phi;
    my $c = cos $phi;
    #    $self->msg ("sin φ = $s, cos φ = $c");
    # Eq. 5.1
    my ($x1d, $y1d) = ($xd * $c + $yd * $s, - $xd * $s + $yd * $c);
    $self->msg ("Rotated midpoint: x1' = $x1d, y1' = $y1d");
    my $factor;
    my $lambda = ($x1d/$rx)**2 + ($y1d/$ry)**2;
    if ($lambda > 1) {
	$self->msg ("$lambda > 1, increasing radii");
	my $sqrtlambda = sqrt ($lambda);

	$rx *= $sqrtlambda;
	$ry *= $sqrtlambda;
	$factor = 0;
    }
    else {
	my $den = ($rx * $y1d)**2 + ($ry * $x1d)**2;
	my $num = ($rx * $ry)**2 - $den;
	#    $self->msg ("den = $den, num = $num");
	$factor = sqrt ($num / $den);
    }
    #    $self->msg ("factor = $factor");
    my $sign = 1;
    if ($fa == $fs) {
	$sign = -1;
    }
    $factor *= $sign;
    my $cxd =   $factor * $rx * $y1d / $ry;
    my $cyd = - $factor * $ry * $x1d / $rx;
    #    $self->msg ("A: transformed centre: ($cxd, $cyd)");
    # Eq 5.3
    my $cx = ($c * $cxd - $s * $cyd) + ($x1 + $x2) / 2;
    my $cy = ($s * $cxd + $c * $cyd) + ($y1 + $y2) / 2;
    $self->msg (sprintf ("A: centre of ellipse: (%.2f, %.2f)", $cx, $cy));
    my @vec1 = (1,0);
    # Eq. 5.5
    my $xv2 = ($x1d - $cxd)/$rx;
    my $yv2 = ($y1d - $cyd)/$ry;
    my @vec2 = ($xv2, $yv2);
    my $theta1 = vangle (\@vec1, \@vec2);
    my $theta1d = rad2deg ($theta1);
    $self->msg (sprintf ("Start angle θ1 = %.2f (%.2f°)", $theta1, $theta1d));
    # Eq. 5.6
    my $xv3 = (-$x1d - $cxd)/$rx;
    my $yv3 = (-$y1d - $cyd)/$ry;
    my @vec3 = ($xv3, $yv3);
    #    $self->msg ("vec2 = @vec2");
    #    $self->msg ("vec3 = @vec3");
    my $dt = vangle (\@vec2, \@vec3);
    my $dtd = rad2deg ($dt);
    $self->msg ("Swept angle initially: Δθ = $dt ($dtd)");
    if ($fs == 0) {

	# if fS = 0 and the right side of (eq. 5.6) is greater than 0,
	# then subtract 360°, whereas if fS = 1 and the right side of
	# (eq. 5.6) is less than 0, then add 360°. In all other cases
	# leave it as is.

	if ($dt > 0) {
	    $dt -= 2*pi;
	}
    }
    elsif ($fs == 1) {
	if ($dt < 0) {
	    $dt += 2*pi;
	}
    }
    $dtd = rad2deg ($dt);
    $self->msg (sprintf ("Swept angle Δθ = %.2f (%.2f°)", $dt, $dtd));

    if ($fs) {
	$cr->arc ($cx, $cy, $rx, $theta1, $theta1+$dt);
    }
    else {
	$cr->arc_negative ($cx, $cy, $rx, $theta1, $theta1+$dt);
    }
}

# Helper for svg_arc

# Eq. 5.4 of
# https://www.w3.org/TR/SVG/implnote.html#ArcImplementationNotes

sub vangle
{
    my ($u, $v) = @_;
    my @u = @$u;
    my @v = @$v;
    my $ulen = vlen ($u);
    my $vlen = vlen ($v);
    my $sign;
    my $vdot = vdot ($u, $v);
    my $cross = vcross ($u, $v);
    if ($cross == 0) {
	if ($vdot < 0) {
	    $sign = -1;
	}
	else {
	    $sign = 1;
	}
    }
    else {
	$sign = $cross / abs ($cross);
    }
    my $value = $vdot / ($ulen * $vlen);
    return $sign * acos ($value);
}

# Helper for vangle

sub vdot
{
    my ($u, $v) = @_;
    return $u->[0] * $v->[0] + $u->[1] * $v->[1];
}

# Helper for vangle

sub vcross
{
    my ($u, $v) = @_;
    return $u->[0] * $v->[1] - $u->[1] * $v->[0];
}

# Helper for vangle

sub vlen
{
    my ($v) = @_;
    return sqrt ($v->[0]**2 + $v->[1]**2);
}

# Quadratic bezier curve shim for Cairo

# Private routine for this module.

sub quadbez
{
    my ($cr, $p2, $p3) = @_;

    if (! $cr->has_current_point ()) {
	# This indicates a bug has happened, because there is always a
	# current point when rendering an SVG path.
	die "Invalid drawing of quadratic bezier without a current point";
    }

    my @p1 = $cr->get_current_point ();
    my @p2_1;
    my @p2_2;

    # https://en.wikipedia.org/wiki/B%C3%A9zier_curve#Degree_elevation

    for my $c (0, 1) {
	$p2_1[$c] = ($p1[$c] + 2 * $p2->[$c]) / 3;
	$p2_2[$c] = ($p3->[$c] + 2 * $p2->[$c]) / 3; 
    }
    $cr->curve_to (@p2_1, @p2_2, @$p3);
}

sub line
{
    my ($self, %attr) = @_;
    my @fields = qw/x1 x2 y1 y2/;
    for (@fields) {
	if (! defined $attr{$_}) {
	    croak "No $_ in line";
	}
    }
    my $cr = $self->{cr};
    $cr->move_to ($attr{x1}, $attr{y1});
    $cr->line_to ($attr{x2}, $attr{y2});
    $self->do_svg_attr (%attr);
}

my %units = (
    # Arbitrary hack
    mm => 4,
    px => 1,
);

sub svg_units
{
    my ($thing) = @_;
    if (! defined $thing) {
	return 0;
    }
    if ($thing eq '') {
	return 0;
    }
    if (looks_like_number ($thing)) {
	return $thing;
    }
    if ($thing =~ /([0-9\.]+)(\w+)/) {
	my $number = $1;
	my $unit = $2;
	my $u = $units{$unit};
	if ($u) {
	    return $number * $u;
	}
    }

    carp "Failed to convert SVG units '$thing'";
    return undef;
}

# We have a path in the cairo surface and now we have to do the SVG
# instructions specified by "%attr".

sub do_svg_attr
{
    my ($self, %attr) = @_;

    # Copy attributes from "self".

    if ($self->{attr}) {
	for my $k (keys %{$self->{attr}}) {
	    if (! $attr{$k}) {
		$attr{$k} = $self->{attr}{$k};
	    }
	    else {
		carp "Not overwriting attribute $k";
	    }
	}
    }

    if ($attr{style}) {
	my @styles = split /;/, $attr{style};
	for (@styles) {
	    my ($key, $value) = split /:/, $_, 2;
	    $attr{$key} = $value;
	}
    }
    my $cr = $self->{cr};
    my $stroke_width = $attr{"stroke-width"};
    if ($stroke_width) {
	$stroke_width = svg_units ($stroke_width);
	$cr->set_line_width ($stroke_width);
    }
    my $linecap = $attr{"stroke-linecap"};
    if ($linecap) {
	$cr->set_line_cap ($linecap);
    }
    my $linejoin = $attr{"stroke-linejoin"};
    if ($linejoin) {
	$cr->set_line_join ($linejoin);
    }
    my $fill = $attr{fill};
    if ($fill) {
	trim_whitespace ($fill);
    }
    if (! $fill) {
	my $svgfill = $self->{svg}{fill};
	if ($svgfill) {
	    $fill = $svgfill;
	}
    }
    my $stroke = $attr{stroke};
    if ($stroke) {
	trim_whitespace ($stroke);
    }
    my $fill_opacity = $attr{'fill-opacity'};
    # Not sure how to handle this yet.
    #    $self->do_fill_stroke ($cr, $fill, $stroke);
}

sub do_fill_stroke
{
    my ($self, $attr) = @_;
    my $cr = $self->{cr};
    my $fill = $attr->{fill};
    my $stroke = $attr->{stroke};

    if ($fill && $fill ne 'none') {
	if ($stroke && $stroke ne 'none') {
	    $self->set_colour ($fill);
	    $cr->fill_preserve ();
	    $self->msg ("Filling with $fill");
	    $self->set_colour ($stroke);
	    $cr->stroke ();
	    $self->msg ("Stroking with $stroke");
	}
	else {
	    $self->set_colour ($fill);
	    $self->msg ("Filling with $fill");
	    $cr->fill ();
	}
    }
    elsif ($stroke && $stroke ne 'none') {
	$self->set_colour ($stroke);
	$cr->stroke ();
    }
    elsif (! $fill && ! $stroke) {
	$self->msg ("Filling with black");
	# Fill with black seems to be the default.
	$self->set_colour ('#000000');
	$cr->fill ();
    }
}

my $gcwtable;
# Only warn once if the module fails.
my $gcwtablefailed;

sub name2colour
{
    my ($colour) = @_;
    if (! $colour) {
	warn "Empty input colour";
	return @defaultrgb;
    }
    if (! $gcwtable) {
	if ($gcwtablefailed) {
	    return @defaultrgb;
	}
	$gcwtable = Graphics::ColorNames::WWW->NamesRgbTable ();
	if (! $gcwtable) {
	    warn "Graphics::ColorNames::WWW->NamesRgbTable failed";
	    $gcwtablefailed = 1;
	    return @defaultrgb;
	}
    }
    my $rgb = $gcwtable->{$colour};
    if (! $rgb) {
	carp "Unknown colour $colour";
	return @defaultrgb;
    }
    return @$rgb;
}

sub set_colour
{
    my ($self, $colour) = @_;
    my $cr = $self->{cr};
    # Hex digit
    my $h = qr/[0-9a-f]/i;
    my $hh = qr/$h$h/;
    my @c = @defaultrgb;
    if ($colour eq 'black') {
	@c = (0, 0, 0);
    }
    elsif ($colour eq 'white') {
	@c = (1, 1, 1);
    }
    elsif ($colour =~ /^#($h)($h)($h)$/) {
	@c = (hex ($1)/15, hex ($2)/15, hex ($3)/15);
    }
    elsif ($colour =~ /^#($hh)($hh)($hh)$/) {
	@c = (hex ($1)/255, hex ($2)/255, hex ($3)/255);
    }
    else {
	@c = name2colour ($colour);
    }
    $cr->set_source_rgb (@c);
}

sub surface
{
    my ($self) = @_;
    return $self->{surface};
}

# Direction of vector from ($cx, $cy) to ($px, $py) in radians

sub point_angle
{
    my ($cx, $cy, $px, $py) = @_;
    return atan2 ($py - $cy, $px - $cx);
}

# Rotate $x and $y anticlockwise by $angle in radians

sub rotate
{
    my ($x, $y, $angle) = @_;
    my $s = sin $angle;
    my $c = cos $angle;
    return ($x * $c - $y * $s, $x * $s + $y * $c);
}

sub msg
{
    my ($self, $msg) = @_;
    if (! $self->{verbose}) {
	return;
    }
    print "$msg\n";
}

sub debugmsg
{
    my (undef, $file, $line) = caller (0);
    printf ("%s:%d: ", $file, $line);
    print "@_\n";
}

1;

