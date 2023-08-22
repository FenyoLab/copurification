use LWP::UserAgent;
my $url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=protein&id=AAA59172.1&rettype=fasta&retmode=text";
my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );
my $response = $ua->get($url);
if ( $response->is_success ) {
	print $response->decoded_content;
}
else {
	die $response->status_line;
}
