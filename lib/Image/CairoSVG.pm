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
1;
