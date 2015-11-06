# This is a test for module Image::CairoSVG.

use warnings;
use strict;
use Test::More;
use Cairo;
use Image::CairoSVG;
use FindBin '$Bin';

my $cairosvg = Image::CairoSVG->new ();
ok ($cairosvg);

my $surface = Cairo::ImageSurface->create ('argb32', 400, 400);
my $cairosvg2 = Image::CairoSVG->new (
    surface => $surface,
);
ok ($cairosvg2);

SKIP: {
    eval {
	require Image::PNG::Libpng;
    };
    if ($@) {
	skip "Image::PNG::Libpng could not be loaded", 2;
    }

    # This uses the function "image_data_diff" from distribution
    # Image::PNG::Libpng to compare the PNG files generated for being
    # exactly the same.

    for my $f (qw/Technical_college Church/) {
	my $surface = Cairo::ImageSurface->create ('argb32', 400, 400);
	my $cairosvg2 = Image::CairoSVG->new (
	    surface => $surface,
	);
	my $stem = "$Bin/$f";
	my $file = "$stem.svg";
	my $testpng = "$stem.png";
	if (! -f $testpng) {
	    die "Required test file '$testpng' is missing";
	}
	$cairosvg2->render ($file);
	my $tempout = "$stem-out.png";
	$surface->write_to_png ($tempout);
	my $diff = Image::PNG::Libpng::image_data_diff ($testpng, $tempout);
	ok (! $diff, "PNG files contain the same data");
	unlink $tempout;
    }
};

done_testing ();

# Local variables:
# mode: perl
# End:
