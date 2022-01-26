#!/usr/bin/perl

use CGI;
use DateTime;
use DateTime::Format::Strptime;

my $cgi = new CGI;
open my $img, '<', 'plot.png';
my $offset;
if(defined $cgi->param('offset')) {
	$offset = $cgi->param('offset');
	$offset =~ s/[^-0-9]//;
} else {
	$offset = 0;
}
if(defined $cgi->param('range')) {
	$range = $cgi->param('range');
	$range =~ s/[^-0-9]//;
} else {
	$range = -1;
}

print STDERR "offset => $offset, range => $range\n";

my $formatter = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d');
my $end_date = DateTime->now(time_zone => 'local', formatter => $formatter)->subtract(seconds => $offset);
my $start_date = 
	($range > 0) ? 
		$end_date->clone()->subtract(seconds => $range) : 
		DateTime->new(year => '2022', formatter => $formatter);
my @dates;
while($start_date <= $end_date) {
	push @dates, $start_date->clone();
	$start_date->add(days => 1);
}
$dates = join ' ', map { "/var/log/temp-humi-$_.dat" } @dates;
print STDERR "cat $dates\n";

#print $cgi->header(-type=>'image/png'),`gnuplot -e "offset=$offset; range=$range" plot.plt`;
print $cgi->header(-type=>'image/png');
open my $img, "cat $dates | gnuplot -e \"offset=$offset; range=$range\" plot.plt |";
while(<$img>) { print }
