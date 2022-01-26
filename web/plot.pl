#!/usr/bin/perl

use warnings;
use strict;
use CGI;
use DateTime;
use DateTime::Format::Strptime;
use Chart::Gnuplot;
use File::Temp;

my $cgi = new CGI;

my $offset;
if(defined $cgi->param('offset')) {
	$offset = $cgi->param('offset');
	$offset =~ s/[^-0-9]//;
} else {
	$offset = 0;
}

my $range;
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

my %data;
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
my $multiplot = Chart::Gnuplot->new(
	output   => $plotfile->filename,
	terminal => 'svg size 1024,1536',
#	timestamp => { fmt => '%m/%d %H:%M' }, #Format for display
#	timeaxis => 'x',
#	xtics => { rotate => -45 },
#	legend => { position => 'outside' },
);
my @plots;
#my $temp_plot = Chart::Gnuplot->new(
print STDERR "Instantiating sub-plots\n";
$plots[0] = Chart::Gnuplot->new(
	timestamp => { fmt => '%m/%d %H:%M' }, #Format for display
	timeaxis => 'x',
	xtics => { rotate => -45 },
	legend => { position => 'outside' },
);
#my $humidity_plot = Chart::Gnuplot->new(
$plots[1] = Chart::Gnuplot->new(
	timestamp => { fmt => '%m/%d %H:%M' }, #Format for display
	timeaxis => 'x',
	xtics => { rotate => -45 },
	legend => { position => 'outside' },
);
#my $pressure_plot = Chart::Gnuplot->new(
$plots[2] = Chart::Gnuplot->new(
	timestamp => { fmt => '%m/%d %H:%M' }, #Format for display
	timeaxis => 'x',
	xtics => { rotate => -45 },
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
print STDERR "Creating datasets\n";
for my $host (keys %data) {
	my @timestamps = map { $_->{'timestamp'} } @{$data{$host}};
	my @temps = map { $_->{'temp'} } @{$data{$host}};
	my @humidities = map { $_->{'humidity'} } @{$data{$host}};
	my @pressures = map { $_->{'pressure'} } @{$data{$host}};
	push @{$datasets{'temp'}}, Chart::Gnuplot::DataSet->new(
		title => $hostnames{$host},
		xdata => \@timestamps, 
		ydata => \@temps, 
		style => 'lines',
		timefmt => '%Y-%m-%d-%H:%M:%S' #Format of input file
	);
	push @{$datasets{'humidity'}}, Chart::Gnuplot::DataSet->new(
		title => $hostnames{$host},
		xdata => \@timestamps, 
		ydata => \@humidities, 
		style => 'lines',
		timefmt => '%Y-%m-%d-%H:%M:%S' #Format of input file
	);
	push @{$datasets{'pressure'}}, Chart::Gnuplot::DataSet->new(
		title => $hostnames{$host},
		xdata => \@timestamps, 
		ydata => \@pressures, 
		style => 'lines',
		timefmt => '%Y-%m-%d-%H:%M:%S' #Format of input file
	);
}

#$temp_plot->add2d(@{$datasets{'temp'}});
#$humidity_plot->add2d(@{$datasets{'humidities'}});
#$pressure_plot->add2d(@{$datasets{'pressures'}});
print STDERR "Plotting datasets\n";
$plots[0]->add2d(@{$datasets{'temp'}}->[0]);
$plots[1]->add2d(@{$datasets{'humidities'}}->[0]);
$plots[2]->add2d(@{$datasets{'pressures'}}->[0]);
#my @plots = ($temp_plot, $humidity_plot, $pressure_plot);
print STDERR "Multiplotting\n";
$multiplot->multiplot(@plots);
#$multiplot->plot2d(@{$datasets{'temp'}});

print STDERR "CGI-ing\n";

print $cgi->header(-type=>'image/svg+xml');
while(<$plotfile>) { print }
