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

=head2 path

    $cairosvg->path (%attr);

=head2 rectangle


=head1 Dependencies

=over

=item L<Cairo>

=item L<Image::SVG::Path>

=item L<XML::Parser>

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
use Image::SVG::Path;
our $VERSION = 0.01;

sub new
{
    return bless {};
}

sub render
{
    my ($self, $file) = @_;
    die unless -f $file;
    my $p = XML::Parser->new (
	Handlers => {
	    Start => sub {
		handle_start ($self, @_);
	    },
	},
    );
    $p->parsefile ($file);
}

sub handle_start
{
    my ($self, $parser, $tag, %attr) = @_;
    if ($tag eq 'path') {
	my $d = $attr{d};
	die unless $d;
	my @path_info = extract_path_info ($d, {
	    absolute => 1,
	    no_shortcuts => 1,
	});
    }
    elsif ($tag eq 'polygon') {
	my $points = $attr{points};
	my @points = split /,|\s+/, $points;
	die if @points % 2 != 0;
    }
    elsif ($tag eq 'line') {
	my ($x1, $x2, $y1, $y2) = @attr{qw/x1 x2 y1 y2/};
    }
    elsif ($tag eq 'svg' ||
	   $tag eq 'title') {
	;
    }
    else {
	print "$tag\n";
    }
}

1;
