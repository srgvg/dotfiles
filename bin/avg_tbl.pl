#!/usr/bin/perl -w

# written by Hendrik De Vloed for Serge van Ginderachter
# scripts take a series of files as arguments
# each file contains a fixed width, space separated table with numbers
# script sums the respective cell from each file and divides it by the number of files
# hence calculating the average cell value over all files

$files=0;
$debug=0;

foreach $filename (@ARGV) {
	$files++;
	open INPUT, "<$filename" or die "Can't open $filename";
	$y=0;
	print "$filename\n" if $debug;
	while(<INPUT>) {
		chomp;
		@data=split;
		for($x=0; $x<@data; $x++) {
			#$avg[$y] = () unless defined $avg[$y];
			$avg[$y][$x] = 0 unless defined $avg[$y][$x];
			$avg[$y][$x] += $data[$x];
			print "$x $y $data[$x] -> $avg[$y][$x]\n" if $debug;
		}
		$y++;
	}
	close INPUT;
}

foreach $row (@avg) {
	print join(" ",map {$_/$files} @$row)."\n";
}
