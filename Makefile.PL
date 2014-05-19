use strict;
use warnings;
use ExtUtils::MakeMaker;

my $pm = 'lib/Image/CairoSVG.pm';
my $github = 'github.com/benkasminbullock/image-cairosvg';
my $repo = "https://$github";

WriteMakefile (
    NAME => 'Image::CairoSVG',
    VERSION_FROM => $pm,
    ABSTRACT_FROM => $pm,
    AUTHOR => 'Ben Bullock <bkb@cpan.org>',
    LICENSE => 'perl',
    PREREQ_PM => {
	'Image::SVG::Path' => '0.16',
	'XML::Parser' => '0',
	'Cairo' => '0',
    },
    META_MERGE => {
	'meta-spec' => {
	    version => 2,
	},
        resources => {
            repository => {
		type => 'git',
		url => "git://$github.git",
		web => $repo,
	    },
            bugtracker => {
		web => "$repo/issues",
	    },
#	    homepage => 'http://',
        },
    },
    MIN_PERL_VERSION => '5.006001',
);
