#!c:/perl/bin/perl.exe
##
##
#use warnings;
use strict;

require "./cgi-bin/common.pl";
require "./cgi-bin/defines.pl";

#create number to sample mapping and vice versa
my %number_to_sample_mapping;
my %sample_to_number_mapping;
# H1-H12 = 1-12, G1-G12 = 13-24, F1-F12 = 25-36, E1-E12 = 37-48, D1-D12 = 49-60, C1-C12 = 61-72, B1-B12 = 73-84, A1-A12 = 85-96
for(my $i = 1; $i <= 96; $i++)
{
    my $sample_id; 
    my $n = int($i/12);
    if ($i%12 == 0) { $n--; }
    $sample_id = $i-(12*$n);
    
    if ($i <= 12)            { $sample_id = "H" . $sample_id; }
    if ($i > 12 && $i <= 24) { $sample_id = "G" . $sample_id; }
    if ($i > 24 && $i <= 36) { $sample_id = "F" . $sample_id; }
    if ($i > 36 && $i <= 48) { $sample_id = "E" . $sample_id; }
    if ($i > 48 && $i <= 60) { $sample_id = "D" . $sample_id; }
    if ($i > 60 && $i <= 72) { $sample_id = "C" . $sample_id; }
    if ($i > 72 && $i <= 84) { $sample_id = "B" . $sample_id; }
    if ($i > 84 && $i <= 96) { $sample_id = "A" . $sample_id; }
    
    $number_to_sample_mapping{"$i"} = $sample_id;
    $sample_to_number_mapping{$sample_id} = "$i";
}

my $line;
my $id;
#my $expect;
my $temp;
my $string;
my $uid = 0;
my $intensity = "_";

my @uid;
my @proteins;
my @mass;
my @pi;
my @I;
my @sequences;
my $sequence;
my $expect;
my @expects;
my $value = 0;
my @pcount;
my %counts;
my $trace;
my @length;
my %coverage;
my @corrected_length;

#cgi params
my $proex = -1;
my $npep = 0;

my %found_proteins = ();

my $base_path = 'C:\\NCDIR\\96-Well\\MS Clustering\\XTandem xml results\\';
if (!opendir(DIR,"$base_path")) { print "Error reading $base_path ($!)\n"; exit(1); }
my @allfiles = readdir DIR;
closedir DIR;
my $repeat = 0;
foreach my $path (@allfiles)
{
	#A1.mzXML.MS2.HCD.2014_09_02_18_54_17.t
	my $sample_id;
	if($path =~ /^([A-Z][0-9][0-9]?)\..+\.xml$/i)
	{ $sample_id = $1; }
	else { next; }
	
	$path = $base_path . '/' . $path;
	
	#init vars for this iteration
	@uid = ();
	@proteins = ();
	@mass = ();
	@pi = ();
	@I = ();
	@sequences = ();
	@expects = ();
	@pcount = ();
	%counts = ();
	@length = ();
	@corrected_length = ();
	%coverage = ();
	
	# READ IN info from XML file
	my $length = 1;
	open(INPUT,"$path") or die "$path not found";
	while(<INPUT>)
	{
		if(/group/is && /type=\"model\"/is)
		{
			$_ = <INPUT>;
			$string = $_;
			$id = get_feature($string,"label");
			$id =~ s/.*?(\S+).*/$1/;
			$uid = get_feature($string,"uid");
			#$pe = get_feature($string,"expect");
			#if($pe >= $proex)
			#{
			#	next;
			#}
			$temp = 0;
			foreach $line(@uid)
			{
				if($line == $uid)
				{
					$temp = 1;
				}
			}
			if($temp == 0)
			{
				push(@proteins,$id);
				push(@uid,$uid);
				$sequence = "";
				$counts{$uid} += 1;
				while($_)
				{
					if(/\<protein/s and /uid=\"$uid\"/s)
					{
						$intensity = get_feature($_,"sumI");
						if($intensity ne "_")
						{
							push(@I,$intensity);
						}
						$expect = get_feature($_,"expect");
						push(@expects, $expect);
						while(not/\<peptide/is)
						{
							$_ = <INPUT>;
						}
						$length = get_feature($_,"end");
						$_ = <INPUT>;
						
						while(not/\<\/peptide/is and not/\<domain/)
						{
							s/\s+//ig;
							$sequence .= $_;
							$_ = <INPUT>;
						}
						
						while($_  and not /\<domain/)
						{
							if(/\<\/group/ or /\<\/peptide/)
							{
							    last; 
							}
							$_ = <INPUT>;
						}
						if(/\<domain/)
						{
						    $string = $_;
						    my $start = get_feature($string,"start");
						    my $end = get_feature($string,"end");
						    $coverage{$uid} .= "$start $end ";
						}
						last;
					}
					$_ = <INPUT>;
				}
				
				while(not /\<\/group/s)
				{
					if(/\<protein/s)
					{
						$uid = get_feature($_,"uid");
						$counts{$uid} += 1;
					}
					$_ = <INPUT>;
				}
				$sequence =~ s/\b//g;
				push(@length,$length);
				push(@corrected_length,unlikely_residues($sequence,"([KR])([^P])",$id));
				push(@sequences,$sequence);	
			}
			else
			{
				$counts{$uid} += 1;
				my $counted = 0;
				$_ = <INPUT>;
				while(not /\<\/group/s)
				{
					if(/\<protein/s)
					{
						$uid = get_feature($_,"uid");
						$counts{$uid} += 1;
					}
					if(/\<domain/ && not $counted)
					{
					    $string = $_;
					    my $start = get_feature($string,"start");
					    my $end = get_feature($string,"end");
					    $coverage{$uid} .= "$start $end ";
					    $counted = 1;
					}
					$_ = <INPUT>;
				}	
			}	
		}
		if(/\<group/ and /label\=\"unused input parameters\"/)
		{
			while($_ and not /\<\/group/ and not /\<\/bioml/)
			{
				chomp($_);
				if(/\<note type\=\"input\" label\=\"gpmdb, .+\"/)
				{
					$value = $_;
					while($_ and not/<\/note/)
					{
						$_ = <INPUT>;
						chomp($_);
						$value .= $_;
					}
					$value =~ s/<note.*?>(.*?)\<\/note\>/$1/;
					$value =~ s/^\t//;
					if(length($value) > 2)
					{
						my ($tag) = $_ =~ /label\=\"gpmdb, (.+)\"/;
						#$gpm_value{$tag} .= "$value";
						#$gpm_show++;
					}
				}
				elsif(/\<note type\=\"input\" label\=\"spectrum, trace\"/)
				{
					$value = $_;
					while($_ and not/<\/note/)
					{
						$_ = <INPUT>;
						chomp($_);
						$value .= $_;
					}
					$value =~ s/<note.*?>(.*?)\<\/note\>/$1/;
					$trace = $value;
				}
				$_ = <INPUT>;
			}
		}
	}
	close(INPUT);
	
	#store the intensities for this sample, adding to found proteins list if needed
	my $l = scalar(@proteins);
	$a = $l-1;
	while($a >= 0)
	{
		$id = $proteins[$a];
		if ($id eq 'YOR098C')
		{
			my $la = 0;
		}
		
		
		my @v = split / /,get_coverage($uid[$a],$length[$a],$corrected_length[$a]);
		if ($v[1] eq "100+" || $v[3] eq "100+") {
			my $la = 1;
		}
		
		$found_proteins{$id}{$sample_id} = [$expects[$a],$I[$a],sprintf("%.1f/%.1f",$v[1],$v[3]),$v[0],$v[2]];
		$a--;
	}	
}

#print to excel format the intensities of each protein found, organized by sample id
my @sample_letters = ("H", "G", "F", "E", "D", "C", "B", "A"); #("A", "B", "C", "D", "E", "F", "G", "H");

my $output_dir = "C:\\NCDIR\\96-Well\\MS Clustering";
my @output_file_names = ("MS_Table-log(e).txt","MS_Table-log(I).txt","MS_Table-coverage.txt","MS_Table-unique_peps.txt","MS_Table-total_peps.txt");
my @fhs;
for my $fn (@output_file_names)
{
	open(my $fh, ">$output_dir/$fn")|| die "Can't open out file $fn";
	push(@fhs, $fh);
}
#my $ms_data_logI = "C:\\NCDIR\\96-Well\\MS Clustering\\MS_Table-log(I).txt";
#open(OUT_LOGI, ">$ms_data_logI") || die "Can't open out file!";
#
#my $ms_data_cov = "C:\\NCDIR\\96-Well\\MS Clustering\\MS_Table-coverage.txt";
#open(OUT_COV, ">$ms_data_cov") || die "Can't open out file!";

#print header
for my $fh (@fhs) { print $fh ","; }

for my $letter (@sample_letters)
{
	for(my $i = 1; $i <= 12; $i++)
	{
		for my $fh (@fhs) { print $fh $sample_to_number_mapping{"$letter$i"} . ','; }
	}
}
for my $fh (@fhs) { print $fh "\n"; }

my @protein_list = keys(%found_proteins);
for my $protein (@protein_list)
{
	for my $fh (@fhs) { print $fh "$protein,"; }
	for my $letter (@sample_letters)
	{
		for(my $i = 1; $i <= 12; $i++)
		{
			my $sample_id = "$letter$i";
			my $index = 0;
			for my $fh (@fhs)
			{
				print $fh "$found_proteins{$protein}{$sample_id}[$index],";
				$index++;
			}
		}
	}
	for my $fh (@fhs) { print $fh "\n"; }
}
for my $fh (@fhs) { close($fh); }

sub get_coverage
{
    my ($_u,$_l,$_cl) = @_;
    my $value = 1.0;
    my @se = split / /,$coverage{$_u};
    my $total = scalar(@se);
    my %p = ();
    my $peps = 0;
    my $a = 0;
    my @seq;
    while($a < $_l+1)   {
        push(@seq,0);
        $a++;
    }
    $a = 0;
    while($a < $total)  {
        my $b = $se[$a];
        if(not $p{"$se[$a] $se[$a+1]"}) {
            $p{"$se[$a] $se[$a+1]"} = 1;
            $peps++;
			while($b < $se[$a+1])   {
				$seq[$b]++;
				$b++;
			}
       }
        $a += 2;
    }   
    $a = 0;
    $value = 0;
    my $cvalue = 0;
    while($a < $_l) {
        if($seq[$a] > 0)    {
            $value++;
        }
        $a++;
    }
    if($_l-$_cl > 0)	{
	    $cvalue = $value * 100/($_l-$_cl);
    }
    else	{
	    $cvalue = "na";
    }
    $value *= 100.0/$_l;
    if($cvalue > 100)	{
	$cvalue = "100+";
    }
    else	{
	$cvalue = sprintf("%.0f",$cvalue);
    }
    if($value < 10) {
        $value = sprintf("%i %.1f %i %s",$peps,$value,$total/2,$cvalue);
    }
    else    {
        $value = sprintf("%i %.0f %i %s",$peps,$value,$total/2,$cvalue);
    }   
    return $value;
}


