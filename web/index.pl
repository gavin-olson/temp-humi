#!/usr/bin/perl

use CGI;

my $cgi = new CGI;

my $offset;
if(defined $cgi->param('offset')) {
	$offset = $cgi->param('offset');
    $offset =~ s/[^-0-9]//;
} else {
    $offset = -1;
}
my $range;
if(defined $cgi->param('range')) {
	$range = $cgi->param('range');
    $range =~ s/[^-0-9]//;
} else {
    $range = -1;
}

print $cgi->header();

print <<EOF;
<html>
<head>
<title>GavHouse Environmental Monitoring</title>
</head>
<body>
<h1>GavHouse Environmental Monitoring</h1>
<div style="width: 1024; margin: 0 auto;">
<span style="align: center;">
	<a href="?range=3600&offset=0">Hour</a> | 
	<a href="?range=86400&offset=0">Day</a> | 
	<a href="?range=-1">All</a> | 
	<a href="?range=$range&offset=@{[$offset+$range]}">&lt;</a> | 
	<a href="?range=$range&offset=@{[$offset-$range]}">&gt;</a> |
	<a href="?range=$range&offset=0">&gt;&gt;</a>
</span><br />
<img src="plot3.pl?field=temp&offset=$offset&range=$range" />
<img src="plot3.pl?field=humidity&offset=$offset&range=$range" />
<img src="plot3.pl?field=pressure&offset=$offset&range=$range" />
</div>
</body>
</html>
EOF
