#!/usr/bin/perl -w
use strict;
use warnings;
use LWP::Simple;

validate("RefSeq", "NP_000537.3", "Homo sapiens");

#validate("RefSeq", "NP_001001998.1", "Homo sapiens");
#validate("RefSeq", "NP_057174.1", "Homo sapiens");
#
#validate("GenBank", "AAH72015.1", "Homo sapiens");
#validate("GenBank", "AAH72016.1", "Homo sapiens");
#
validate("GenBank", "7157", "Homo sapiens");
validate("GenBank", "7159", "Homo sapiens");
#validate("GenBank", "10177", "Homo sapiens");
#validate("GenBank", "10178", "Homo sapiens");
#validate("GenBank", "10179", "Homo sapiens");
#validate("GenBank", "22916", "Homo sapiens");
#validate("GenBank", "AAF66821.1", "Homo sapiens");
#validate("GenBank", "AAH72017.1", "Homo sapiens");
#validate("GenBank", "CAA53270.1", "Homo sapiens");
#validate("GenBank", "AAA51622.1", "Homo sapiens");
#
#validate("RefSeq", "NP_418415.1", "Escherichia coli");
#
#validate("GenBank", "CAA23626.1", "Escherichia coli");
#validate("GenBank", "CAA23625.1", "Escherichia coli");
#validate("GenBank", "CAA23613.1", "Escherichia coli");

sub validate
{
    my $db_name = $_[0];
    my $name = $_[1];
    my $species = $_[2];
    my $version = ""; #used in refseq/genbank
    
    my $common_name = ""; my $ret = 0;
    if($db_name eq 'RefSeq')
    {
        $ret = validate_refseq($name, $common_name, $version, $species);
        if($ret) { print "'$name', '$common_name', '$version', '$species'\n"; }
        else { print "not found\n"; }
    }
    elsif($db_name eq 'GenBank')
    {
        $ret = validate_genbank_gene($name, $common_name, $version, $species);
        if($ret) { print "'$name', '$common_name', '$version', '$species'\n"; }
        else
        {
            $ret = validate_refseq($name, $common_name, $version, $species);
            if($ret) { print "'$name', '$common_name', '$version', '$species'\n"; }
            else { print "not found\n"; }
        }
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
    
    #https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=protein&id=NP_001001998.1&rettype=fasta&retmode=text
    my $query_str = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=protein&id=' . $name . '&rettype=fasta&retmode=text';
    
    my $content = get($query_str);
    my $found = 0;
    if(defined $content)
    {#parse fasta for organism, common name
        print $content;
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
    
    if($found) { return 1; }
    else { return 0; }
}

sub validate_genbank_gene
{
    my $name = $_[0];
    my $species = $_[3];
    $_[2] = "";
    
    #https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=gene&id=7157&rettype=gene_table&retmode=text
    my $query_str = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=gene&id=' . $name . '&rettype=gene_table&retmode=text';
    
    my $content = get($query_str);
    my $found = 0;
    if(defined $content)
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

