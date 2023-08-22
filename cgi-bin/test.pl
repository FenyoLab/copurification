#!/usr/bin/perl
# test.cgi by Bill Weinman [http://bw.org/]
# Copyright 1995-2008 The BearHeart Group, LLC
# Free Software: Use and distribution under the same terms as perl.

use strict;
use warnings;
use CGI;

print foreach (
    "Content-Type: text/plain\n\n",
    "BW Test version 5.0\n",
    "Copyright 1995-2008 The BearHeart Group, LLC\n\n",
    "Versions:\n=================\n",
    "perl: $]\n",
    "CGI: $CGI::VERSION\n"
);

my $q = CGI::Vars();
print "\nCGI Values:\n=================\n";
foreach my $k ( sort keys %$q ) {
    print "$k [$q->{$k}]\n";
}

print "\nEnvironment Variables:\n=================\n";
foreach my $k ( sort keys %ENV ) {
    print "$k [$ENV{$k}]\n";
}

print 'DEVEL ====';
if(open(DEVEL_OUT, ">>", "/var/www/data_v2_0/dev_log.txt") || die "Could not open file $!")
{
	*STDERR = *DEVEL_OUT;

	select(DEVEL_OUT);
	$|++; # autoflush DEVEL_OUT
	select(STDOUT);
	
	my $now_string = localtime;
	print DEVEL_OUT "Log opened: $now_string\n";
}
#else
#{
	#$DEVELOPER_VERSION = 0;
	#open(STDERR, "NUL"); 
#}
