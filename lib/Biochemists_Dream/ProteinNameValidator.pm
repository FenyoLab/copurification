#!c:/perl/bin/perl.exe

#    (Biochemists_Dream::ProteinNameValidator) ProteinNameValidator.pm - validates Protein Systematic Names
#    online at www.ncbi.nlm.nih.gov & yeastmine.yeastgenome.org/yeastmine/service
#
#    Copyright (C) 2015  Sarah Keegan
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
use warnings;

package Biochemists_Dream::ProteinNameValidator; 
#given a protein 'systematic' name, and a database name,
#this package will link to the db and check that this protein name exists
#and also get the protein common name to fill in the database

use LWP::Simple;
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

#NOTE: should change ncbi access to use fasta file as in below string, for protein NP_057174.1
#http://www.ncbi.nlm.nih.gov/protein/NP_057174.1?report=fasta&log$=seqview&format=text

sub validate
{#
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
        $ret = validate_genbank_protein($name, $common_name, $version, $species);
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

sub validate_refseq
{
    my $name = $_[0];
    my $species = $_[3];
    $_[2] = "";
    my $query_str = 'http://www.ncbi.nlm.nih.gov/protein/' . $name;
    
    my $content = get($query_str);
    my $found = 0;
    if(defined $content)
    {#parse fasta for organism, common name
        while($content =~ s/NCBI Reference Sequence:\s*([^\s^<]+)[\s<]//)
        {
            my $t1 = $1; my $t2 = $t1; my $version = "";
            if($t2 =~ s/\.([0-9]+)$//) 
            {#remove version number from the end, and save it
                $version = $1;
            }
            
            if($name eq $t1 || $name eq $t2)
            {
                if($content =~ /<h1>\s*(.+)\s*\[$species.*\]\s*<\/h1>/)
                {
                    $_[1] = $1;
                    $found = 1;
                    
                    #if name from data file has no version number, use the one found in DB lookup
                    if($version && $name eq $t2) 
                    { $_[2] = $version; }
                    
                    last;
                }
            }  
        }
    }
    if($found) { return 1; }
    else { return 0; }
}

sub validate_genbank_gene
{
    my $name = $_[0];
    my $species = $_[3];
    $_[2] = "";
    my $query_str = 'http://www.ncbi.nlm.nih.gov/gene/' . $name;
    
    my $content = get($query_str);
    my $found = 0;
    if(defined $content)
    {#parse fasta for organism, common name
        #<span class="geneid">Gene ID: 10179, updated on 26-Jan-2014</span>
        while($content =~ s/Gene ID:\s*([^\s^<^,]+)//)
        {
            my $t1 = $1; my $t2 = $t1; my $version = "";
            if($t2 =~ s/\.([0-9]+)$//) 
            {#remove version number from the end, and save it
                $version = $1;
            }
            
            if($name eq $t1 || $name eq $t2)
            {
                #<title>RBM7 RNA binding motif protein 7 [Homo sapiens (human)] - Gene - NCBI</title>
                if($content =~ /<title>\s*(.+)\s*\[$species.*\]\s*-\s*Gene\s*-\s*NCBI\s*<\/title>/)
                {
                    $_[1] = $1;
                    $found = 1;
                    
                    #if name from data file has no version number, use the one found in DB lookup
                    if($version && $name eq $t2) 
                    { $_[2] = $version; }
                    
                    last;
                }
            }  
        }
    }
    if($found) { return 1; }
    else { return 0; }
    
}

sub validate_genbank_protein
{
    my $name = $_[0];
    my $species = $_[3];
    $_[2] = "";
    my $query_str = 'http://www.ncbi.nlm.nih.gov/protein/' . $name;
    
    my $content = get($query_str);
    my $found = 0;
    if(defined $content)
    {#parse fasta for organism, common name
        while($content =~ s/GenBank:\s*([^\s^<]+)[\s<]//)
        {
            my $t1 = $1; my $t2 = $t1; my $version = "";
            if($t2 =~ s/\.([0-9]+)$//) 
            {#remove version number from the end, and save it
                $version = $1;
            }
            
            if($name eq $t1 || $name eq $t2)
            {
                if($content =~ /<h1>\s*(.+)\s*\[$species.*\]\s*<\/h1>/)
                {
                    $_[1] = $1;
                    $found = 1;
                    
                    #if name from data file has no version number, use the one found in DB lookup
                    if($version && $name eq $t2) 
                    { $_[2] = $version; }
                    
                    last;
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