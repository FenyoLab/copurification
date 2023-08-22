#!c:/perl/bin/perl.exe 
# Compares lanes in gels - input params tell which lanes and which gels to compare

use warnings;
use strict;

my $dir = "C:\\NCDIR\\96-Well\\data_v2_0\\6\\Experiments\\230"; #\\209";
my $html_dir = 'zhanna_gels_project_1_comparison_230';

# gel1 is Nup1_matrix4_filt_original_bottomleft: D1,C1,D2,C2,...
# gel2 is Nup1_matrix4_filt_original_bottomright: B1,A1,B2,A2,...
# gel3 is Nup1_matrix4_filt_original_topleft: H1,G1,H2,G2,...
# gel4 is Nup1_matrix4_filt_original_topright: F1,E1,F2,E2,...
#my @gels = ("gel1", "gel2", "gel3", "gel4");
my @gels = ("gel2", "gel1", "gel4", "gel3");
my %lane_to_sample_mapping;
$lane_to_sample_mapping{"gel1"} = ["D", "C"];
$lane_to_sample_mapping{"gel2"} = ["B", "A"];
$lane_to_sample_mapping{"gel3"} = ["H", "G"];
$lane_to_sample_mapping{"gel4"} = ["F", "E"];
my @sample_letters = ("A", "B", "C", "D", "E", "F", "G", "H");

my $html_file = "C:/NCDIR/96-Well/html/lane_coding.html";
if (open(OUT, ">$html_file"))
{
    print OUT "<html><head></head><body><table border=1><tr>";

    my $gel_i = 0;
    foreach my $gel (@gels)
    {
	if ($gel_i == 2)
	{
	    print OUT "<br></tr></table><table border=1><tr>";
	}
	
	my @i_list = (3,2,5,4,7,6,9,8,11,10,13,12,15,14,17,16,19,18,21,20,23,22,25,24);
	for(my $ii = 0; $ii <= $#i_list; $ii++)
	{
	    my $i = $i_list[$ii];
	    my $index = $i % 2 == 0 ? 0 : 1;
	    my $sample_id = $lane_to_sample_mapping{$gel}[$index] . int($i/2);
	    #gel4.lane.14.nn
	    my $cur_file = "$gel.lane.$i.nn.png";
	    
	    print OUT "<td>$sample_id<br><img src='$html_dir/$cur_file'></td>";
	    
	}
	$gel_i++;
    }
    print OUT "</tr></table></body></html>";
    
}

