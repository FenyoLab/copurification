#!c:/perl/bin/perl.exe 
# Compares lanes in gels - input params tell which lanes and which gels to compare

use warnings;
use strict;

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

#my $dir = "C:\\NCDIR\\96-Well\\data_v2_0\\6\\Experiments\\222";
my $dir = "C:\\NCDIR\\96-Well\\data_v2_0\\6\\Experiments\\230"; #228"; #216";  #227";
my $html_dir = 'zhanna_gels_project_1_comparison_230'; #228'; #_227'; #'john_gels_project_2';
my @gels = ("gel1", "gel2", "gel3", "gel4");

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
	    while ($line=<IN>)
	    {
		if ($line=~/^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)/)
		{#mass	pixel	min	max	cen	sum	max	amount
		    my $mass = $1;
		    my $intensity = $6;
		    
		    my $mass_error = get_default_mass_error($mass);
		    my $min_diff = $mass_error;
		    my $min_diff_j = -1;
		    
		    
		    for(my $j = 0; $j <= $#master_mass_list; $j++)
		    {
			my $diff = abs($master_mass_list[$j] - $mass);
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
			$master_mass_list[$min_diff_j] += $mass;
			$master_mass_list[$min_diff_j] /= 2;
			$mass_lanes{"$min_diff_j"}{"$gel.lane-details.$i.txt"} = 1; #$intensity; #$mass;
			
		    }
		    else
		    {
			push @master_mass_list, $mass;
			my $new_j = $#master_mass_list;
			$mass_lanes{"$new_j"}{"$gel.lane-details.$i.txt"} = 1; #$intensity; #$mass;
		    }
		}   
	    }
	    close(IN);
	}
    }
}

my @sorted_master_mass_list = sort {$b <=> $a} @master_mass_list;
for(my $i = 0; $i <= $#sorted_master_mass_list; $i++)
{
    my $error = get_default_mass_error($sorted_master_mass_list[$i]);
    print "$sorted_master_mass_list[$i], $error\n";
}

my $js_file = "$dir/js_text.txt";
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
		for(my $i = 0; $i <= $#master_mass_list; $i++)
		{
		    my $master_mass = $master_mass_list[$i];
		    $master_mass =~ /(\d+\.\d\d)/;
		    $master_mass = $1;
		    if (defined $mass_lanes{"$i"}{$cur_file})
		    {
			my $matching_mass = $mass_lanes{"$i"}{$cur_file};
			#$matching_mass =~ /(\d+\.\d\d)/;
			#$matching_mass = $1;
			print OUT ",'$master_mass':$matching_mass";
		    }
		    else
		    {
			print OUT ",'$master_mass':0";
		    }
		    
		}
		print OUT "},\n";
		
		
	    }
	}
    print OUT "] ;\n\n";
}

print OUT "vectors[i] = [ ";
for(my $i = 0; $i <= $#master_mass_list; $i++)
{
    my $master_mass = $master_mass_list[$i];
    $master_mass =~ /(\d+\.\d\d)/;
    $master_mass = $1;
    if ($i != $#master_mass_list)
    {
	print OUT "data[i]['$master_mass'], ";
    }
    else
    {
	print OUT "data[i]['$master_mass'] ];\n";
    }
    
    
}
#vectors[i] = [ data[i]['129.93'] , data[i]['70.19'], data[i]['91.55'], data[i]['19.43'], data[i]['46.88'], data[i]['387.40'], data[i]['56.34'], data[i]['296.31'], data[i]['209.07'], data[i]['37.07'], data[i]['29.31'], data[i]['14.47'], data[i]['459.64'], data[i]['10.92'] ] ;
close(OUT);     
  

