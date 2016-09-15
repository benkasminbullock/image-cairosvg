#!/home/ben/software/install/bin/perl
use warnings;
use strict;
use FindBin '$Bin';
use Cairo;
use Image::CairoSVG;
my $surface = Cairo::ImageSurface->create ('argb32', 200, 450);
my $cairosvg = Image::CairoSVG->new (
    surface => $surface,
);
$cairosvg->render ("$Bin/locust.svg");
$surface->write_to_png ("$Bin/locust.png");
