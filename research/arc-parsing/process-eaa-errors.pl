#!/home/ben/software/install/bin/perl
use Z;
my $text = read_text ("$Bin/eaa-errors.txt");
my $indir = "/home/ben/software/SuperTinyIcons/images/svg";
print <<EOF;
my \@paths = (
EOF
while ($text =~ /(\w+)\.png failed:.*multiple of 7/g) {
    my $file = $1;
    my $svg = "$indir/$file.svg";
    if (! -f $svg) {
	warn "No $svg";
	next;
    }
    my $svgtext = read_text ($svg);
    if ($svgtext !~ /\bd="(.*?)"/) {
	die "No d in $svgtext";
    }
    my $path = $1;
    print "{\n    file => '$file.svg',\n";
    print "    path => '$path',\n},\n";
}
print <<EOF;
);
EOF
