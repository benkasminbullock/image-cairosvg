# This is a test for module Image::CairoSVG.

use warnings;
use strict;
use Test::More;
use Image::CairoSVG;

my $cairosvg = Image::CairoSVG->new ();
ok ($cairosvg);

done_testing ();
# Local variables:
# mode: perl
# End:
