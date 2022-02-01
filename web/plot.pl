#!/usr/bin/perl

use Time::HiRes qw/ time /;
use warnings;
use strict;
use CGI::Fast qw/ :standard /;
use DateTime;
use DateTime::Format::Strptime;
use Chart::Gnuplot;
use File::Temp;

sub process_request {
my $last_time = time;

#my $cgi = new CGI;
my $cgi = shift;

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

my $this_time = time;
print STDERR sprintf("Read CGI parameters: %fs\n", $this_time-$last_time );
$last_time = $this_time;

$offset = 0;
$range = 86400;

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

$this_time = time;
print STDERR sprintf("Generate date list of %d entries: %fs\n", scalar @dates, $this_time-$last_time );
$last_time = $this_time;

my %data;
for my $date (@dates) {
	open my $file, '<', "/var/log/temp-humi-$date.dat" or next;
	while(<$file>) {
		my (
			$timestamp,
			$hostname,
			$temp,
			undef,
			$humidity,
			undef,
			$battery,
			undef,
			$pressure,
			undef
		) = split ',';
		
		if($temp ne '') {
			push @{$data{'temp'}{$hostname}}, {
				'timestamp' => $timestamp,
				'value'     => $temp
			};
		}
		if($humidity ne '') {
			push @{$data{'humidity'}{$hostname}}, {
				'timestamp' => $timestamp,
				'value'     => $humidity
			};
		}
		if($pressure ne '') {
			push @{$data{'pressure'}{$hostname}}, {
				'timestamp' => $timestamp,
				'value'     => $pressure
			};
		}
	}
}

$this_time = time;
print STDERR sprintf("Ingest data: %fs\n", $this_time-$last_time );
$last_time = $this_time;

my $plotfile = File::Temp->new(SUFFIX => '.svg');
my $multiplot = Chart::Gnuplot->new(
	output    => $plotfile->filename,
	terminal  => 'svg size 1024,1536',
);

my %hostnames = (
	'192.168.135.190' => { name => 'Garage', color => 'red' },
	'192.168.135.191' => { name => 'Basement', color => 'blue' },
	'192.168.135.192' => { name => 'Bedroom', color => 'green' },
	'192.168.135.193' => { name => 'Living Room', color => 'orange' },
	'192.168.135.194' => { name => 'Office', color => 'cyan' }
);
my @plots;
my $xtic_fmt = '%H:%M';
if($range >= 86400) {
	$xtic_fmt = "%m/%d $xtic_fmt";
}
for my $field ('temp', 'humidity', 'pressure') {
	my $plot = Chart::Gnuplot->new(
		title     => ucfirst $field,
		timeaxis  => 'x',
		xtics     => { rotate => -45, labelfmt => $xtic_fmt },
		xrange    => [ $start_date, $end_date ],
		grid      => { width => 1, linetype => 'dot', color => 'gray' },
		legend    => { position => 'outside' },
	);

	my @datasets;
	for my $host (sort keys %hostnames) {
		my @field_data = map { $_->{'value'} } @{$data{$field}{$host}};
		my @timestamp_data = map { $_->{'timestamp'} } @{$data{$field}{$host}};
		
		#print STDERR join ',',@field_data;
		
		if(@field_data > 0) {
			push @datasets, Chart::Gnuplot::DataSet->new(
	 			title => $hostnames{$host}->{'name'},
	 			color => $hostnames{$host}->{'color'},
				xdata => \@timestamp_data, 
				ydata => \@field_data, 
				style => 'lines',
				timefmt => '%Y-%m-%d-%H:%M:%S' #Format of input file
			);
		}
	}
	$plot->add2d(@datasets);
	push @plots, [$plot];
}

$this_time = time;
print STDERR sprintf("Generate datasets/subplots: %fs\n", $this_time-$last_time );
$last_time = $this_time;

# Multiplot wants a 2D array of plot objects or a reference to an array of
# array references to define the matrix of sub-plots
$multiplot->multiplot(\@plots);

$this_time = time;
print STDERR sprintf("Plot data: %fs\n", $this_time-$last_time );
$last_time = $this_time;

print $cgi->header(-type=>'image/svg+xml');
while(<$plotfile>) { print }

$this_time = time;
print STDERR sprintf("Dump plot to CGI: %fs\n", $this_time-$last_time );
$last_time = $this_time;

#print STDERR sprintf("TTL time: %fs\n", $this_time-$ttl_start );
}

while(my $cgi = CGI::Fast->new) {
	process_request($cgi);
}

