#!c:/perl/bin/perl.exe 
# Compares lanes in gels - input params tell which lanes and which gels to compare

use warnings;
use strict;

my $MANUAL_BAND_METHOD = 1;

sub get_default_mass_error
{#gets mass error based on mass, uses function derived from mass errors of a sample gel
 #uses max-mass = 200 and max-error = 36
	my $mass = shift;
	return get_mass_error($mass, 36, 200);
	
}

sub get_mass_error
{#gets mass error based on mass, uses function derived from mass errors of a sample gel
 #uses a line passing through (0,0) and (m,max(mass_error)* 1.5) , and the line y=max(mass_error)* 1.5 after mass=m
	my $multiplier = 1.5; #.5; #1.5; #1;
	my $mass = shift;
	my $max_mass_error = shift;
	my $max_mass = shift;
	
	if ($mass > $max_mass)
	{#curve levels off after mass=$max_mass
		return $max_mass_error * $multiplier;
	}
	my $x1 = $max_mass;
	my $y1 = $max_mass_error * $multiplier;
	
	my $mass_error = ($y1/$x1) * ($mass-$x1) + $y1;
	return $mass_error;
	
}

my $dir = "C:\\NCDIR\\96-Well\\data_v2_0\\6\\Experiments\\230"; #\\209";

# gel1 is Nup1_matrix4_filt_original_bottomleft: D1,C1,D2,C2,...
# gel2 is Nup1_matrix4_filt_original_bottomright: B1,A1,B2,A2,...
# gel3 is Nup1_matrix4_filt_original_topleft: H1,G1,H2,G2,...
# gel4 is Nup1_matrix4_filt_original_topright: F1,E1,F2,E2,...
my @gels = ("gel1", "gel2", "gel3", "gel4");
my @grouping_masses = (301.42, 262.47, 222.84, 148.29, 136.25, 88.01, 63.25, 50.74, 41.80, 34.89, 26.26, 17.02);

#for manual method
#my @grouping_masses_lower = (253, 189, 146, 145, 126, 101, 87, 79, 72, 62, 57, 47, 45, 43, 41, 36, 29, 27, 23, 20, 18, 16);
#my @grouping_masses_upper = (278, 218, 183, 157, 139, 113, 96, 85, 75, 67, 60, 51, 46, 44, 42, 39, 32, 29, 26, 22, 19, 17);

my @grouping_masses_lower = (253, 189, 146, 145, 126, 101, 87, 79, 72, 62, 56, 47, 41, 36, 29, 20, 16);
my @grouping_masses_upper = (278, 218, 183, 157, 139, 113, 96, 85, 75, 68, 60, 51, 46, 39, 32, 29, 19);

my %lane_to_sample_mapping;

$lane_to_sample_mapping{"gel1"} = ["D", "C"];
$lane_to_sample_mapping{"gel2"} = ["B", "A"];
$lane_to_sample_mapping{"gel3"} = ["H", "G"];
$lane_to_sample_mapping{"gel4"} = ["F", "E"];

my @sample_letters = ("A", "B", "C", "D", "E", "F", "G", "H");

my %sample_masses;
foreach my $gel (@gels)
{
    for(my $i = 2; $i <= 25; $i++)
    {
        my $index = $i % 2 == 0 ? 0 : 1;
        my $sample_id = $lane_to_sample_mapping{$gel}[$index] . int($i/2);
        my $cur_file = "$dir/$gel.lane-details.$i.txt";
        if (open(IN, $cur_file))
        {
            my $line=<IN>;
	    my %matched_indexes;
            while ($line=<IN>)
            {
                if ($line=~/^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)/)
		{#mass	pixel	min	max	cen	sum	max	amount
                    my $mass = $1;
                    my $intensity = $6;
                    $mass =~ /(\d+\.\d\d)/;
                    $mass = $1;
		    $intensity =~ /(\d+\.\d\d)/;
                    $intensity = $1;
		    
		    if ($MANUAL_BAND_METHOD)
		    {
			for(my $j = 0; $j <= $#grouping_masses_lower; $j++)
			{
			    if ($mass >= $grouping_masses_lower[$j] && $mass < $grouping_masses_upper[$j])
			    {
				if (not defined $matched_indexes{"$j"})
				{#if was not already matched by a more intense lane, we found the match, otherwise keep looking
				    $matched_indexes{"$j"} = 1;
				    #$mass_lanes{"$j"}{"$gel.lane-details.$i.txt"} = 1; #$intensity; #$intensity; #$mass;
				    $sample_masses{"$grouping_masses_lower[$j]-$sample_id"} = $intensity;
				    last;
				}
			    }
			}
		    }
		    else
		    {
			my $mass_error = get_default_mass_error($mass);
			my $min_diff = $mass_error;
			my $min_diff_j = -1;
			for(my $j = 0; $j <= $#grouping_masses; $j++)
			{#find the best match to a reference mass
			    my $diff = abs($grouping_masses[$j] - $mass);
			    if ($diff < $mass_error)
			    {
				if ($diff < $min_diff)
				{
				    $min_diff = $diff;
				    $min_diff_j = $j;
				}
			    }
			}
			if ($min_diff_j != -1)
			{
			    $sample_masses{"$grouping_masses[$min_diff_j]-$sample_id"} = $intensity;
			    
			}
		    }
		    
		    
		    
                }   
            }
        }
    }
}

if (!$MANUAL_BAND_METHOD)
{ @grouping_masses = sort { $a <=> $b } @grouping_masses; }

my $cur_file = "$dir/sample_mass_table_grouped_4.txt";
if (open(OUT, ">$cur_file"))
{
    print OUT "\t";
    
    for(my $j = 0; $j <= $#sample_letters; $j++)
    {
        for(my $k = 1; $k <= 12; $k++)
        {
            print OUT "$sample_letters[$j]" . "$k\t";
        }
    }
    print OUT "\n";
    
    if ($MANUAL_BAND_METHOD)
    {
	for(my $i = 0; $i <= $#grouping_masses_lower; $i++)
	{
	    my $ave = ($grouping_masses_lower[$i] + $grouping_masses_upper[$i]) / 2;
	    print OUT "$ave\t";
	    for(my $j = 0; $j <= $#sample_letters; $j++)
	    {
		for(my $k = 1; $k <= 12; $k++)
		{
		    my $sample_id = "$sample_letters[$j]" . $k;
		    if(defined $sample_masses{"$grouping_masses_lower[$i]-$sample_id"})
		    {
			print OUT $sample_masses{"$grouping_masses_lower[$i]-$sample_id"};
			print OUT "\t";
		    }
		    else { print OUT "\t"; }
		}
	    }
	    print OUT "\n";
	    
	}
    }
    else
    {
	for(my $i = 0; $i <= $#grouping_masses; $i++)
	{
	    print OUT "$grouping_masses[$i]\t";
	    for(my $j = 0; $j <= $#sample_letters; $j++)
	    {
		for(my $k = 1; $k <= 12; $k++)
		{
		    my $sample_id = "$sample_letters[$j]" . $k;
		    if(defined $sample_masses{"$grouping_masses[$i]-$sample_id"})
		    {
			print OUT $sample_masses{"$grouping_masses[$i]-$sample_id"};
			print OUT "\t";
		    }
		    else { print OUT "\t"; }
		}
	    }
	    print OUT "\n";
	    
	}
	
    }
    
}

