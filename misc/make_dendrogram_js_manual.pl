#!c:/perl/bin/perl.exe 
# Compares lanes in gels - input params tell which lanes and which gels to compare

use warnings;
use strict;

#my $dir = "C:\\NCDIR\\96-Well\\data_v2_0\\6\\Experiments\\222";
my $dir = "C:\\NCDIR\\96-Well\\data_v2_0\\6\\Experiments\\230"; #228"; #216";  #227";
my $html_dir = 'zhanna_gels_project_1_comparison_230'; #228'; #_227'; #'john_gels_project_2';
my @gels = ("gel1", "gel2", "gel3", "gel4");

#my @grouping_masses_lower = (253, 189, 146, 145, 126, 101, 87, 79, 72, 62, 57, 47, 45, 43, 41, 36, 29, 27, 23, 20, 18, 16);
#my @grouping_masses_upper = (278, 218, 183, 157, 139, 113, 96, 85, 75, 67, 60, 51, 46, 44, 42, 39, 32, 29, 26, 22, 19, 17);

my @grouping_masses_lower = (253, 189, 146, 145, 126, 101, 87, 79, 72, 62, 57, 47, 41, 36, 29, 20, 16);
my @grouping_masses_upper = (278, 218, 183, 157, 139, 113, 96, 85, 75, 67, 60, 51, 46, 39, 32, 29, 19);


my $IDENTITY_MATCH = 0;

my @master_mass_list;
my %mass_lanes;
foreach my $gel (@gels)
{
    for(my $i = 2; $i < 26; $i++)
    {
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
		    
		    for(my $j = 0; $j <= $#grouping_masses_lower; $j++)
		    {
			if ($mass >= $grouping_masses_lower[$j] && $mass < $grouping_masses_upper[$j])
			{
			    if (not defined $matched_indexes{"$j"})
			    {#if was not already matched by a more intense lane, we found the match, otherwise keep looking
				$matched_indexes{"$j"} = 1;
				$mass_lanes{"$j"}{"$gel.lane-details.$i.txt"} = ($IDENTITY_MATCH ? 1 : $intensity); 
				last;
			    }
			}
		    }
		}   
	    }
	    close(IN);
	}
    }
}

my $js_file;
if($IDENTITY_MATCH)
{
    $js_file = "$dir/js_text_manual_identity.txt";
}
else
{
    $js_file = "$dir/js_text_manual_intensity.txt";
}

if (open(OUT, ">$js_file"))
{
    print OUT "var data = [ \n";
    foreach my $gel (@gels)
    {
	for(my $j = 2; $j < 26; $j++)
	{
	    my $cur_file = "$gel.lane-details.$j.txt";
	    my $image_html = qq!<img src="./$html_dir/$gel.lane.$j.n.png" width="24" height="300" />!; 
		    
	    print OUT "{'lane_file':'$image_html'";
	    for(my $i = 0; $i <= $#grouping_masses_lower; $i++)
	    {
		my $mass_label = "$grouping_masses_lower[$i]-$grouping_masses_upper[$i]";
		if (defined $mass_lanes{"$i"}{$cur_file})
		{
		    my $matching_value = $mass_lanes{"$i"}{$cur_file};
		    if (!$IDENTITY_MATCH)
		    {
			$matching_value =~ /(\d+\.\d\d)/;
			$matching_value = $1;
		    }
		    print OUT ",'$mass_label':$matching_value";
		}
		else
		{
		    print OUT ",'$mass_label':0";
		}
	    }
	    print OUT "},\n";
	}
    }
    print OUT "] ;\n\n";
}

print OUT "vectors[i] = [ ";

for(my $i = 0; $i <= $#grouping_masses_lower; $i++)
{
    my $mass_label = "$grouping_masses_lower[$i]-$grouping_masses_upper[$i]";
    if ($i != $#grouping_masses_lower)
    {
	print OUT "data[i]['$mass_label'], ";
    }
    else
    {
	print OUT "data[i]['$mass_label'] ];\n";
    }	
    
}
close(OUT);     
  

