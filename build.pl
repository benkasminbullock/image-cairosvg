#!/home/ben/software/install/bin/perl
use warnings;
use strict;
use FindBin '$Bin';
use Perl::Build;
perl_build (
#    pod => ['lib/Image/CairoSVG.pod',],
    make_pod => "$Bin/make-pod.pl",
    clean => "$Bin/clean.pl",
);
exit;
