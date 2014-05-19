=encoding UTF-8

=head1 NAME

Image::CairoSVG - abstract here.

=head1 SYNOPSIS

This example converts an SVG into a PNG:

    use Cairo;
    use Image::CairoSVG;
    my $surface = Cairo::ImageSurface->new ();
    my $cairosvg = Image::CairoSVG->new (
        surface => $surface,
    );
    $cairosvg->render ('file.svg');

=head1 DESCRIPTION

=head1 METHODS

=head2 new

=head2 render

Draw an SVG into a Cairo surface.

=head2 line

    $cairosvg->line (%attr);

Given SVG input of the form C<< <line > >>, this renders it onto the
Cairo surface.

=head2 path

    $cairosvg->path (%attr);

=head2 rectangle

    $cairosvg->rectangle (%attr);

=head1 Dependencies

=over

=item L<Cairo>

This is the renderer.

=item L<Image::SVG::Path>

This is used for parsing the "path" information of the SVG.

=item L<XML::Parser>

This is used for parsing the SVG itself.

=back

=head1 SEE ALSO

=head2 CPAN

=head2 Other

=head3 CairoSVG

L<http://cairosvg.org/|CairoSVG> is a Python SVG renderer in Cairo.

=cut

package Image::CairoSVG;
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw//;
%EXPORT_TAGS = (
    all => \@EXPORT_OK,
);
use warnings;
use strict;
use Carp;
use XML::Parser;
use Cairo;
use Image::SVG::Path 'extract_path_info';
our $VERSION = 0.01;

our $default_surface_type = 'argb32';
our $default_surface_size = 100;

=head2 new

    my $cairosvg = Image::CairoSVG->new (
        surface => Cairo::ImageSurface->create ('argb32', 100, 100)
    );

If a surface is not provided, this creates a L<Cairo::ImageSurface> of
dimensions 100 by 100 of rgba format.

=cut

sub new
{
    my ($class, %options) = @_;
    my $surface = $options{surface};
    if (! $surface) {
	$surface = Cairo::ImageSurface->create (
	    $default_surface_type,
	    $default_surface_size,
	    $default_surface_size,
	);
    }
    my $self = {};
    $self->{surface} = $surface;
    $self->{cr} = Cairo::Context->create ($self->{surface});
    if (! $self->{cr}) {
	die "Cairo::Context->create failed";
    }
    return bless $self;
}

=head2 render

    $self->render ($file);

Render F<$file> onto the Cairo surface of C<$self>.

=cut

sub render
{
    my ($self, $file) = @_;
    die unless -f $file;
    my $p = XML::Parser->new (
	Handlers => {

	    # I think (may be wrong) we only need to handle "start"
	    # tags for SVG. As far as I know, everything in SVG is a
	    # "start" tag plus attributes.

	    Start => sub {
		handle_start ($self, @_);
	    },
	},
    );
    my $cr = $self->{cr};

    if (! $cr) {
	die "No context in $self";
    }
    $p->parsefile ($file);
}

# Start tag handler for the XML parser. This is private.

sub handle_start
{
    my ($self, $parser, $tag, %attr) = @_;

    if ($tag eq 'path') {
	$self->path (%attr);
    }
    elsif ($tag eq 'polygon') {
	$self->polygon (%attr);
    }
    elsif ($tag eq 'line') {
	$self->line (%attr);
    }
    elsif ($tag eq 'svg' ||
	   $tag eq 'title') {
	;
    }
    else {
	warn "Unknown tag '$tag'";
    }

    # http://www.princexml.com/doc/7.1/svg/
    # g, rect, circle, ellipse, line, polyline, polygon, path, text, tspan

}

=head2 polygon

    $cairosvg->polygon (%attr);

=cut

sub polygon
{
    my ($self, %attr) = @_;
    my $points = $attr{points};
    my @points = split /,|\s+/, $points;
    die if @points % 2 != 0;

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
    $self->do_stupid_svg_crap (%attr);
}

=head2 path

    $cairosvg->path (%attr);

Given an SVG path element, send its attribute key / value pairs as
C<%attr> to render into the Cairo surface of C<$cairosvg>.

=cut

sub path
{
    my ($self, %attr) = @_;

    # Get and parse the "d" attribute from the path.

    my $d = $attr{d};
    croak "No d in path" unless $d;
    my @path_info = extract_path_info ($d, {
	absolute => 1,
	no_shortcuts => 1,
    });

    # Cairo context.

    my $cr = $self->{cr};

    if (! $cr) {
	die "No context in $self";
    }

    for my $element (@path_info) {

	# for my $k (sort keys %$element) {
	#     print "$k -> $element->{$k}\n";
	# }
	# print "\n";

	# http://www.lemoda.net/cairo/cairo-tutorial/camel.html

	my $key = $element->{svg_key};

	if ($key eq lc $key) {
	    # This is a bug, "extract_path_info" above should never
	    # return a lower-case key.
	    die "Path parse conversion to absolute failed";
	}
	if ($key eq 'S') {
	    # This is a bug, "extract_path_info" above should never
	    # return a shortcut key.
	    die "Path parse conversion to no shortcuts failed";
	}

	if ($key eq 'M') {
	    $cr->new_sub_path ();
	    $cr->move_to (@{$element->{point}});
	}
	elsif ($key eq 'L') {
	    my $point = $element->{point};
	    my ($x, $y) = @{$point};
	    die unless defined $x && defined $y;
	    $cr->line_to ($x, $y);
	}
	elsif ($key eq 'C') {
	    $cr->curve (@{$element->{control1}},
			@{$element->{control2}},
			@{$element->{end}});
	}
	elsif ($key eq 'Z') {
	    $cr->close_path ();
	}
	elsif ($key eq 'Q') {
	    # Cairo doesn't support quadratic bezier curves so we have
	    # to shim this
	    quadbez ($cr, $element->{control}, $element->{end});
	}
	else {
	    croak "Unknown SVG path key '$key'";
	}
    }
    $self->do_stupid_svg_crap (%attr);
}

# Quadratic bezier curve shim for Cairo

# Private routine for this module.

sub quadbez
{
    my ($cr, $p2, $p3) = @_;

    if (! $cr->has_current_point ()) {
	# This is a bug, there is always a current point when
	# rendering an SVG path.
	die "Invalid drawing of quadratic bezier without a current point";
    }


    my @p1 = $cr->get_current_point ();
    my @p2_1;
    my @p2_2;
    my @p3;

    # https://en.wikipedia.org/wiki/B%C3%A9zier_curve#Degree_elevation

    for my $c (0, 1) {
	$p2_1[$c] = ($p1[$c] + 2 * $p2->[$c]) / 3;
	$p2_2[$c] = ($p3->[$c] + 2 * $p2->[$c]) / 3; 
    }
    $cr->curve_to (@p2_1, @p2_2, @$p3);
}

=head2 line

    $cairosvg->line (%attr);

Render an SVG line onto the surface specified by C<$cairosvg>.

=cut

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
    $self->do_stupid_svg_crap (%attr);
}

sub convert_svg_units
{
    my ($self, $thing) = @_;
    if ($thing =~ /(\d+)px/) {
	$thing =~ s/px$//;
	return $thing;
    }
    die "Dunno what to do with $thing";
}

# We have a path in the cairo surface and now we have to do the SVG
# crap specified by "%attr".

sub do_stupid_svg_crap
{
    my ($self, %attr) = @_;
    confess "Nothing to do" unless keys %attr > 0;

    my $fill = $attr{fill};
    my $stroke = $attr{stroke};
    my $cr = $self->{cr};
    my $stroke_width = $attr{"stroke-width"};
    if ($stroke_width) {
	$stroke_width = $self->convert_svg_units ($stroke_width);
	$cr->set_line_width ($stroke_width);
    }
    if ($fill && $fill ne 'none') {
	if ($stroke && $stroke ne 'none') {
	    $cr->fill_preserve ();
	    $cr->stroke ();
	}
	else {
	    $cr->fill ();
	}
    }
    elsif ($stroke && $stroke ne 'none') {
	$cr->stroke ();
    }
}


sub surface
{
    my ($self) = @_;
    return $self->{surface};
}

1;
