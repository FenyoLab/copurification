#!/usr/bin/perl

#BEGIN {
#    $INC{'IO::Socket::INET6'} = undef;
#}

use strict;
use warnings;

use LWP::UserAgent;

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

print "Calling get_url: $query_str, $content.\n";
my $success = get_url($query_str, $content);

#print "success = $success\n";
#print "query = $query_str\n";
#print "content = $content\n";

sub get_url
{
        my $url = shift;
        my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );
        $ua->timeout(3);
        my $response = $ua->get($url);
        if ( $response->is_success )
        {
                print "Success.\n";
                print "success = ",$response->is_success,"\n";
                print "query = $url\n";
                print "content = ",$response->decoded_content,"\n";
                
                
                #if(open(my $fh, '>', '/Users/sarahkeegan/Dropbox/response.html'))
                #{
                #     print $fh $response->decoded_content;
                #}
                #else { print "file open error: $!\n"; }
                
                
                
                $_[1]=$response->decoded_content;
                return 1;
        }
        else
        {
                
                print "FAILED.\n";
                print "success = ", $response->is_success, "\n";
                print "query = $url\n";
                print "content = ", $response->decoded_content, "\n";

                #die $response->status_line;
                $_[1]= $response->status_line;
                return 0;
        }
}
