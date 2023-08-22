#!/usr/bin/perl

######################################################################
# This is an automatically generated script to run your query.
# To use it you will require the InterMine Perl client libraries.
# These can be installed from CPAN, using your preferred client, eg:
#
#    sudo cpan Webservice::InterMine
#
# For help using these modules, please see these resources:
#
#  * https://metacpan.org/pod/Webservice::InterMine
#       - API reference
#  * https://metacpan.org/pod/Webservice::InterMine::Cookbook
#       - A How-To manual
#  * http://www.intermine.org/wiki/PerlWebServiceAPI
#       - General Usage
#  * http://www.intermine.org/wiki/WebService
#       - Reference documentation for the underlying REST API
#
######################################################################

use strict;
use warnings;

# Set the output field separator as tab
$, = "\t";
# Print unicode to standard out
binmode(STDOUT, 'utf8');
# Silence warnings when printing null fields
no warnings ('uninitialized');

# This code makes use of the Webservice::InterMine library.
# The following import statement sets MouseMine as your default
use Webservice::InterMine::Simple; # 1.0405 'http://www.mousemine.org/mousemine';
my $service = get_service('http://www.mousemine.org/mousemine/service');
my $query = $service->new_query;

# The view specifies the output columns
$query->add_view("Gene.symbol","Gene.organism.name");

$query->add_constraint({
    path  => 'Gene.primaryIdentifier',
    op    => '=',
    value => 'MGI:1925567',
    code        => 'A'});

#$query->add_constraint({
#    path        => 'Gene.organism',
#    op          => 'LOOKUP',
#    value       => 'Mus Musculus',
#    extra_value => 'null',
#    code        => 'B'});

my @rows = $query -> results_table;
if($#rows >= 0)
{ 
    print $rows[0][0];
    print "\n";
    print $rows[0][1];
}
else { print "Error not found.\n"; }
    
# Edit the code below to specify your own custom logic:
# $query->set_logic('A and B');

# Use an iterator to avoid having all rows in memory at once.
#my $it = $query->iterator();
#while (my $row = <$it>) {
#    print $row->{'name'}, "\n";
#}
