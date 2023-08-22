#!/usr/bin/perl

#BEGIN {
#    $INC{'IO::Socket::INET6'} = undef;
#}

use strict;
use warnings;

use LWP::Simple;

my $query_str;
my $content="";

if($#ARGV >= 0)
{
        if ($ARGV[0] == 1)
        {
            $query_str = "https://www.ncbi.nlm.nih.gov";
            #$query_str = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=protein&id=9967&rettype=fasta&retmode=text&api_key=0bfda73ede6d8456979a51783a63ad69fa09";
        }
        else
        {
            $query_str = 'https://www.cpan.org';
        }
        
}
else
{
	$query_str = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=protein&id=9967&rettype=fasta&retmode=text&api_key=0bfda73ede6d8456979a51783a63ad69fa09";
	#	$query_str = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi/?db=protein&id=9967&rettype=fasta&retmode=text";
}

print "Calling get_url: $query_str, $content\n";
my $success = get_url($query_str, $content);

#print "success = $success\n";
#print "query = $query_str\n";
#print "content = $content\n";

sub get_url
{
        my $url = shift;
        print `curl $url`;
        #my $content = get($url) or die 'Unable to get page';
        exit 0;
}
