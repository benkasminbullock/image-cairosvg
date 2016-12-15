#!/home/ben/software/install/bin/perl
use warnings;
use strict;
use utf8;
use FindBin '$Bin';
use lib '/home/ben/projects/image-cairosvg/lib';
use Image::CairoSVG;
use Cairo;
my $in = 'johnny-automatic-bag-of-money.svg';
my $cairosvg = Image::CairoSVG->new ();
my $surface = $cairosvg->render ($in);
$surface->write_to_png ("$Bin/bag.png");
