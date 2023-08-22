#!c:/perl/bin/perl.exe 
# Compares lanes in gels - input params tell which lanes and which gels to compare

use warnings;
use strict;

my $dir = "C:\\NCDIR\\96-Well\\data_v2_0\\6\\Experiments\\227"; #\\209";

# gel1 is Nup1_matrix4_filt_original_bottomleft: D1,C1,D2,C2,...
# gel2 is Nup1_matrix4_filt_original_bottomright: B1,A1,B2,A2,...
# gel3 is Nup1_matrix4_filt_original_topleft: H1,G1,H2,G2,...
# gel4 is Nup1_matrix4_filt_original_topright: F1,E1,F2,E2,...
my @gels = ("gel1", "gel2", "gel3", "gel4");

my %lane_to_sample_mapping;

$lane_to_sample_mapping{"gel1"} = ["D", "C"];
$lane_to_sample_mapping{"gel2"} = ["B", "A"];
$lane_to_sample_mapping{"gel3"} = ["H", "G"];
$lane_to_sample_mapping{"gel4"} = ["F", "E"];

my @sample_letters = ("A", "B", "C", "D", "E", "F", "G", "H");

my %sample_masses;
my @all_masses;
my %used_masses;
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
            while ($line=<IN>)
            {
                if ($line=~/^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)/)
		{#mass	pixel	min	max	cen	sum	max	amount
                    my $mass = $1;
                    my $intensity = $6;
                    $mass =~ /(\d+\.\d\d)/;
                    $mass = $1;
                    #push @{$sample_masses{"$sample_id"}}, [$mass, $intensity];
                    $sample_masses{"$mass-$sample_id"} = $intensity;
                    if (not $used_masses{$mass})
                    {
                        push @all_masses, $mass;
                        $used_masses{$mass} = 1;
                    }
                    
                    
                }   
            }
        }
    }
}
@all_masses = sort { $a <=> $b } @all_masses;
my $cur_file = "$dir/sample_mass_table.txt";
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
    
    for(my $i = 0; $i <= $#all_masses; $i++)
    {
        print OUT "$all_masses[$i]\t";
        for(my $j = 0; $j <= $#sample_letters; $j++)
        {
            for(my $k = 1; $k <= 12; $k++)
            {
                my $sample_id = "$sample_letters[$j]" . $k;
                if(defined $sample_masses{"$all_masses[$i]-$sample_id"})
                {
                    print OUT $sample_masses{"$all_masses[$i]-$sample_id"};
                    print OUT "\t";
                }
                else { print OUT "\t"; }
            }
        }
        print OUT "\n";
        
    }
}

