#!/usr/bin/perl

#    (Biochemists_Dream::ProteinNameValidator) ProteinNameValidator.pm - validates Protein Systematic Names
#    online at www.ncbi.nlm.nih.gov & yeastmine.yeastgenome.org/yeastmine/service
#
#    Copyright (C) 2017  Sarah Keegan
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
#use warnings;

package Biochemists_Dream::ProteinNameValidator; 
#given a protein 'systematic' name, and a database name,
#this package will link to the db and check that this protein name exists
#and also get the protein common name to fill in the database

#use LWP::Simple;
use LWP::UserAgent;
use Webservice::InterMine::Simple;

use lib "../";

BEGIN {

require Exporter;

# set the version for version checking
our $VERSION = 1.00;

# Inherit from Exporter to export functions and variables
our @ISA = qw(Exporter);

# Functions and variables which are exported by default
our @EXPORT = qw(validate);

# Functions and variables which can be optionally exported
our @EXPORT_OK = qw();

}

# exported package globals go here


# non-exported package globals go here
# (they are still accessible as $Some::Module::stuff)

# functions

sub validate
{
    my $db_name = $_[0];
    my $name = $_[1];
    my $species = $_[2];
    my $version = ""; #used in refseq/genbank
    
    my $common_name = ""; my $ret = 0;
    if($db_name eq 'SGD')
    {
        $ret = validate_sgd($name, $common_name, $species);
    }
    elsif($db_name eq 'RefSeq')
    {
        $ret = validate_refseq($name, $common_name, $version, $species);
    }
    elsif($db_name eq 'GenBank')
    {
        $ret = validate_refseq($name, $common_name, $version, $species);
        if (!$ret) { $ret = validate_genbank_gene($name, $common_name, $version, $species); }
    }
    elsif($db_name eq 'MGI')
    {
        $ret = validate_mgi($name, $common_name, $species);
    }
    
    $_[3] = $common_name;
    $_[4] = $version;
    
    return $ret;
}

sub get_url
{
	my $url = shift;
	my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );
    $ua->timeout(0.1);
    
	my $response = $ua->get($url);
	if ( $response->is_success ) 
	{
		return $response->decoded_content;
	}
	else
    {
        #die $response->status_line;
        return "";
    }
}

sub validate_refseq
{
    my $name = $_[0];
    my $species = $_[3];
    $_[2] = "";
    
    #https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=protein&id=9967&rettype=fasta&retmode=text&api_key=0bfda73ede6d8456979a51783a63ad69fa09
    #my $query_str = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=protein&id=AAB59367&rettype=fasta&retmode=text&api_key=0bfda73ede6d8456979a51783a63ad69fa09";
    
    my $query_str = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=protein&id=' . $name . '&rettype=fasta&retmode=text&api_key=0bfda73ede6d8456979a51783a63ad69fa09';
    
    #open(DEVEL_OUT2, ">>/var/www/data_v2_0/dev_log4.txt");
    #print DEVEL_OUT2 "refseq: Calling wget: $query_str.\n";
    #close(DEVEL_OUT2);
    
    my $content="";
    
    #my $content = get_url($query_str); # USE wget INSTEAD TO AVOID ISSUES WITH LWP/PERL 1/23/2022
    my $content = `wget -qO - \"$query_str\"`;
    
    #open(DEVEL_OUT2, ">>/var/www/data_v2_0/dev_log4.txt");
    #print DEVEL_OUT2 "refseq: Finished wget: $content.\n";
    #close(DEVEL_OUT2);

    my $found = 0;
    if($content) 
    {#parse fasta for organism, common name
        #print $content;
        if($content =~ />([^\s]+)\s([^\[]*)\s\[([^\]]+)\]/)
        {
            my $input_name1 = $1; my $common_name = $2; my $input_species = $3; my $version = "";
            my $input_name2 = $input_name1;
            if($input_name2 =~ s/\.([0-9]+)$//) 
            {#remove version number from the end, and save it
                $version = $1;
            }
            if($name eq $input_name1 || $name eq $input_name2)
            {
                if ($input_species =~ /^$species.*$/i)
                {#matches species
                    $_[1] = $common_name;
                    $found = 1;
                    
                    #if name from data file has no version number, use the one found in DB lookup
                    if($version && $name eq $input_name2) 
                    { $_[2] = $version; }
                }  
            }
            
        }
        
    }
    
    #open(DEVEL_OUT2, ">>/var/www/data_v2_0/dev_log4.txt");
    #print DEVEL_OUT2 "refseq: found: $found.\n";
    #close(DEVEL_OUT2);
    
    if($found) { return 1; }
    else { return 0; }
}

sub validate_genbank_gene
{
    my $name = $_[0];
    my $species = $_[3];
    $_[2] = "";
    
    #https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=gene&id=7157&rettype=gene_table&retmode=text
    my $query_str = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=gene&id=' . $name . '&rettype=gene_table&retmode=text&api_key=0bfda73ede6d8456979a51783a63ad69fa09';
    my $content="";
    
    #open(DEVEL_OUT2, ">>/var/www/data_v2_0/dev_log2.txt");
    #print DEVEL_OUT2 "genbank: Calling get_url: $query_str, $content.\n";
    #close(DEVEL_OUT2);
    
    #my $content = get_url($query_str);  # USE wget INSTEAD TO AVOID ISSUES WITH LWP/PERL 1/23/2022
    my $content = `wget -qO - \"$query_str\"`;
    
    my $found = 0;
    if($content)
    {
        #print $content;
        if($content =~ /^([^\[]+)\[([^\]]+)\][\n\r]+Gene ID:\s*([^,]+)/i)
        {
            my $common_name = $1; my $input_species = $2; my $input_name1 = $3;
            my $input_name2 = $input_name1; my $version = "";
            if($input_name2 =~ s/\.([0-9]+)$//) 
            {#remove version number from the end, and save it
                $version = $1;
            }
            if($name eq $input_name1 || $name eq $input_name2)
            {
                if ($input_species =~ /^$species.*$/i)
                {#matches species
                    $_[1] = $common_name;
                    $found = 1;
                    
                    #if name from data file has no version number, use the one found in DB lookup
                    if($version && $name eq $input_name2) 
                    { $_[2] = $version; }
                }
            }   
        }
        
    }
    if($found) { return 1; }
    else { return 0; }
    
}

sub validate_sgd
{
    my $name = $_[0];
    my $species = $_[2];
    my $service = get_service('http://yeastmine.yeastgenome.org/yeastmine/service');
    my $query = $service->new_query;

    $query->add_view(qw/
        Protein.symbol
        Protein.genes.symbol /); #1st gives Nup1p, 2nd gives NUP1?

    $query->add_constraint(
        path  => 'Protein.secondaryIdentifier',
        op    => '=',
        value => $name);
    
    $query->add_constraint(
        path        => 'Protein.organism',
        op          => 'LOOKUP',
        value       => $species);

    my @rows = $query -> results_table;
    if($#rows != 0) { return 0; } #protein not found or > 1 protein found
   
    $_[1] = $rows[0]->[1];
    return 1;
}

sub validate_mgi
{
    my $name = $_[0];
    my $species = $_[2];
    my $service = get_service('http://www.mousemine.org/mousemine/service');
    #use Webservice::InterMine 1.0405 'http://www.mousemine.org/mousemine';

    my $query = $service->new_query; #(class => 'Gene');

    $query->add_view("Gene.symbol","Gene.organism.name");
    
    $name = uc($name);
    if ($name != /^MGI:/)
    {
        $name = 'MGI:' . $name;
    }
    
    $query->add_constraint(
        path  => 'Gene.primaryIdentifier',
        op    => '=',
        value => $name);
    
    my @rows = $query -> results_table;
    if($#rows == 0 && uc($rows[0][1]) eq uc($species))
    { 
        $_[1] = $rows[0][0];
    }
    else { return 0; }
    
    return 1;
}

END { ; } # module clean-up code here (global destructor)

1; # don't forget to return a true value from the file
