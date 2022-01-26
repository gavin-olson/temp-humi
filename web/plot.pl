#!/usr/bin/perl

use warnings;
use strict;
use CGI;
use DateTime;
use DateTime::Format::Strptime;
use Chart::Gnuplot;
use File::Temp;

my $cgi = new CGI;

my $field;
if(defined $cgi->param('field')) {
	$field = $cgi->param('field');
	$field =~ s/[^a-zA-Z0-9]//g;
} else {
	$field = 'temp';
}

my $offset;
if(defined $cgi->param('offset')) {
	$offset = $cgi->param('offset');
	$offset =~ s/[^-0-9]//g;
} else {
	$offset = 0;
}

my $range;
if(defined $cgi->param('range')) {
	$range = $cgi->param('range');
	$range =~ s/[^-0-9]//g;
} else {
	$range = -1;
}

print STDERR "field => $field, offset => $offset, range => $range\n";

my $date_formatter = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d');
my $datetime_formatter = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d-%H:%M:%S');

my $end_date = DateTime->now(time_zone => 'local', formatter => $datetime_formatter)->subtract(seconds => $offset);
my $start_date = 
	($range > 0) ? 
		$end_date->clone()->subtract(seconds => $range) : 
		DateTime->new(year => '2022', formatter => $datetime_formatter);
my @dates;
for(my $cursor_date = $start_date->clone()->set_formatter($date_formatter); $cursor_date <= $end_date; $cursor_date->add(days => 1)) {
	push @dates, $cursor_date->clone();
}

print STDERR "Time from $start_date to $end_date\n";

my %data;
print STDERR join ',', @dates;
print STDERR "\n";
for my $date (@dates) {
	open my $file, '<', "/var/log/temp-humi-$date.dat" or next;
	while(<$file>) {
		my @fields = split ',';
	    push @{$data{$fields[1]}}, {
			'timestamp' => $fields[0],
		    'temp'      => $fields[2],
		    'humidity'  => $fields[4],
		    'battery'   => $fields[6],
		    'pressure'  => $fields[8]
		};
	}
}

my $plotfile = File::Temp->new(SUFFIX => '.svg', UNLINK => 0);
my $plot = Chart::Gnuplot->new(
	output   => $plotfile->filename,
	title => $field,
	terminal => 'svg size 1024,512',
	timestamp => { fmt => '%m/%d %H:%M' }, #Format for display
	timeaxis => 'x',
	xtics => { rotate => -45 },
	xrange => [ $start_date, $end_date ],
	legend => { position => 'outside' },
);


my %datasets;
my %hostnames = (
	'192.168.135.190' => 'Garage',
	'192.168.135.191' => 'Basement',
	'192.168.135.192' => 'Bedroom',
	'192.168.135.193' => 'Living Room',
	'192.168.135.194' => 'Office',
);
for my $host (sort keys %data) {
	my @series_data = grep { $_->{$field} ne '' } @{$data{$host}};
	my @field_data = map { $_->{$field} } @series_data;
	my @timestamp_data = map { $_->{'timestamp'} } @series_data;

	if(@field_data > 0) {
		push @{$datasets{$field}}, Chart::Gnuplot::DataSet->new(
	 		title => $hostnames{$host},
			xdata => \@timestamp_data, 
			ydata => \@field_data, 
			style => 'lines',
			timefmt => '%Y-%m-%d-%H:%M:%S' #Format of input file
		);
	}
}

$plot->plot2d(@{$datasets{$field}});

print $cgi->header(-type=>'image/svg+xml');
while(<$plotfile>) { print }
