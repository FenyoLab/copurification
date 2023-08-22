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
	#$query_str = 'https://raw.githubusercontent.com/MarkGrivainis/dotfiles/master/vimrc';
	#$query_str = 'http://gbfs.citibikenyc.com/gbfs/gbfs.json';
}

print "Calling get_url: $query_str, $content\n";
my $success = get_url($query_str, $content);

#print "success = $success\n";
#print "query = $query_str\n";
#print "content = $content\n";

sub get_url
{
        my $url = shift;
        my $ua = LWP::UserAgent->new();# ssl_opts => { verify_hostname => 0 } );
        #my $agent = $ua->agent;
        #$ua->agent('Mozilla/5.0 ');
        $ua->agent('curl/7.64.0');
        #$ua->proxy(['https', 'http'], 'http://copurification.org:8001/');
		$ua->timeout(0.1);
		#print $ua->head($url)->as_string;
        #my $response = $ua->get($url);
        my $req = HTTP::Request->new(GET => $url);
        my $response = $ua->request($req);
        print $response->status_line;
        if ( $response->is_success or die )
        {
                print "Success.\n";
                print "success = ",$response->is_success,"\n";
                print "is_server = ",$response->is_server_error,"\n";
                print "message = ", $response->as_string, "\n";
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
               	die $response->status_line; 
                print "FAILED.\n";
                print "success = ", $response->is_success, "\n";
                print "query = $url\n";
                print "content = ", $response->decoded_content, "\n";

                #die $response->status_line;
                $_[1]= $response->status_line;
                return 0;
        }
}
