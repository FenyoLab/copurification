#!c:/perl/bin/perl.exe

sub numerically { $a <=> $b; }
sub numericallydesc { $b <=> $a; }

my $gel_directory;
my $gel_image_filename_root;
my $calibration_filename;
my $new_bands_file;

$gel_directory = "$ARGV[0]";
$gel_image_filename_root = "$ARGV[1]";
$calibration_filename = "$ARGV[2]";
$new_bands_file = "$ARGV[3]";

open(LOG, ">$gel_directory/$gel_image_filename_root.calc_new_bands_mass_amt.log.txt") || die "Could not open log file ($gel_directory/$gel_image_filename_root.calc_new_bands_mass_amt.log.txt).\n";
print LOG "begin calc new bands\n";

#read in the calibration information:
if(!open(IN, "$gel_directory/$calibration_filename"))
{
	print LOG "Error: Could not open calibration text file: '$gel_directory/$calibration_filename'.\n";
	exit(1);
}

#the number of mass calibration lanes
my $line = <IN>; chomp($line); $line =~ s/^\s+//; $line =~ s/\s+$//;
my $num_calibration_lanes = $line;

#the lane number of the mass calibration lanes
$line = <IN>; chomp($line); $line =~ s/^\s+//; $line =~ s/\s+$//;
my @calibration_lane_nums;
for(my $i = 0; $i < $num_calibration_lanes && $line =~ s/^([0-9]+)\s*//; $i++) { $calibration_lane_nums[$i] = $1; }

#ladder masses
$line = <IN>; chomp($line); $line =~ s/^\s+//; $line =~ s/\s+$//;
my @calibration_lane_ladders;
for(my $i = 0; $i < $num_calibration_lanes && $line =~ s/^([0-9\.,]+)\s*//; $i++)
{
	@{$calibration_lane_ladders[$i]} = split(',', $1);
}

#the number of amount calibration lanes
$line = <IN>; chomp($line); $line =~ s/^\s+//; $line =~ s/\s+$//;
my $num_amt_calibration_lanes = $line;

#the lane number of the amount calibration lanes
$line = <IN>; chomp($line); $line =~ s/^\s+//; $line =~ s/\s+$//;
my @amt_calibration_lane_nums;
for(my $i = 0; $i < $num_amt_calibration_lanes && $line =~ s/^([0-9]+)\s*//; $i++) { $amt_calibration_lane_nums[$i] = $1; }

#the amount of the amount calibration lanes
$line = <IN>; chomp($line); $line =~ s/^\s+//; $line =~ s/\s+$//;
my @calibration_lane_amts;
for(my $i = 0; $i < $num_amt_calibration_lanes && $line =~ s/^([0-9\.]+)\s*//; $i++) { $calibration_lane_amts[$i] = $1; }

#the calibration lane masses
$line = <IN>; chomp($line); $line =~ s/^\s+//; $line =~ s/\s+$//;
my @calibration_lane_masses;
for(my $i = 0; $i < $num_amt_calibration_lanes && $line =~ s/^([0-9\.]+)\s*//; $i++) { $calibration_lane_masses[$i] = $1; }

close(IN);

#sort ladders for use in calibration functions
my @calibration_lane_sorted_ladders;
for(my $i = 0; $i < $num_calibration_lanes; $i++)
{
	@{$calibration_lane_sorted_ladders[$i]} = sort numericallydesc @{$calibration_lane_ladders[$i]};
}

my @cal_lane_peaks_sorted; # 2 d array, each pos. contains the set of sorted "peaks" found for the calibration lane 
# read in the mass calibration info for each calibration lane (that was calculated and saved by find_lane_masses.pl)
for(my $i = 0; $i < $num_calibration_lanes; $i++)
{	
	if(open(IN, "$gel_directory/$gel_image_filename_root.lane-mass-cal.$calibration_lane_nums[$i].txt"))
	{
		my $line=<IN>;
		while($line=<IN>)
		{
			$line =~ s/\r\n//g;
			chomp($line);
			if ($line=~/^([^\t]+)\t([^\t]+)/)
			{
				push @{$cal_lane_peaks_sorted[$i]}, $2;
			}
		}
		close(IN);
		@{$cal_lane_peaks_sorted[$i]} = sort numerically @{$cal_lane_peaks_sorted[$i]};
	}
	else
	{
		print LOG "Error: Could not open calibration info text file: '$gel_directory/$gel_image_filename_root.lane-mass-cal.$calibration_lane_nums[$i].txt'.\n"; 
		exit(1);
	}
}

#read in the new bands information
my @new_bands_lane_num;
my @new_bands_y_pos;
my @new_bands_top;
my @new_bands_height;
my $header='';
if(open(IN, "$gel_directory/$new_bands_file"))
{
	$header=<IN>;
	$header =~ s/\r\n//g;
	chomp($header);
	while($line=<IN>)
	{
		$line =~ s/\r\n//g;
		chomp($line);
		if ($line=~/^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)/)
		{
			push @new_bands_lane_num, $1;
			push @new_bands_y_pos, $2;
			push @new_bands_top, $3;
			push @new_bands_height, $4;
		}
	}
	close(IN);
}
else
{
	print "Error: Could not open new bands text file: '$gel_directory/$new_bands_file'.\n";
	exit(1);
}


###########################################################################################################
print LOG "num_calibration_lanes: $num_calibration_lanes\n";
print LOG "calibration_lane_nums: ";
for(my $i = 0; $i < $num_calibration_lanes; $i++) { print LOG "$calibration_lane_nums[$i] "; }
print LOG "\n";
print LOG "Ladder masses:\n";
for(my $i = 0; $i < $num_calibration_lanes; $i++)
{
	print LOG join ',', @{$calibration_lane_ladders[$i]};
	print LOG ' ';
}
print LOG "\n";
print LOG "num_amt_calibration_lanes: $num_amt_calibration_lanes\n";
print LOG "amt_calibration_lane_nums: ";
for(my $i = 0; $i < $num_amt_calibration_lanes; $i++) { print LOG "$amt_calibration_lane_nums[$i] "; }
print LOG "\ncalibration_lane_amounts: ";
for(my $i = 0; $i < $num_amt_calibration_lanes; $i++) { print LOG "$calibration_lane_amts[$i] "; }
print LOG "\n";
print LOG "\ncalibration_lane_masses: ";
for(my $i = 0; $i < $num_amt_calibration_lanes; $i++) { print LOG "$calibration_lane_masses[$i] "; }
print LOG "\n";
print LOG "mass calibration info: \n";
for(my $i = 0; $i < $num_calibration_lanes; $i++)
{
	print LOG "lane $calibration_lane_nums[$i]: ";
	for(my $j=0;$j<scalar(@{$cal_lane_peaks_sorted[$i]});$j++)
	{
		print LOG "$cal_lane_peaks_sorted[$i][$j],";
	}
	print LOG "\n";
}

print LOG "new bands: \n";
for(my $i=0;$i < scalar(@new_bands_lane_num);$i++)
{
	print LOG "$new_bands_lane_num[$i], $new_bands_y_pos[$i]\n";
}

###########################################################################################################

#for each of the new bands, calibrate using mass info
my @new_bands_cal_mass;
my @new_bands_cal_mass_error;
for(my $i = 0; $i < scalar(@new_bands_y_pos); $i++)
{
	my $cen = $new_bands_y_pos[$i];
	#print "$cen\n";
	my @cal_mass;
	for(my $i = 0; $i < $num_calibration_lanes; $i++) 
	{
		my $cal_lane_num = $calibration_lane_nums[$i]; 
		my $calpeaks_count = $#{$cal_lane_peaks_sorted[$i]}+1;
		my @ladder_sorted = @{$calibration_lane_sorted_ladders[$i]};
		
		my $mass=0;
		my $l;
		
		#start at smallest pixel, stop when cen <= current peak (l is the index of smallest peak bigger than current cen)
		for($l=0;$l<$calpeaks_count and $cen>$cal_lane_peaks_sorted[$i][$l];$l++) { ; }
		
		
		if ($cen<$cal_lane_peaks_sorted[$i][0])
		{#if current cen < smallest cal lane peak
			
			$mass = $ladder_sorted[0] +
				($cal_lane_peaks_sorted[$i][0]-$cen) * 
					($ladder_sorted[0]-$ladder_sorted[1]) / 
						($cal_lane_peaks_sorted[$i][1]-$cal_lane_peaks_sorted[$i][0]);
			
		}
		else
		{
			if ($cen>$cal_lane_peaks_sorted[$i][$calpeaks_count-1])
			{#if current cen > biggest cal lane peak
				$mass = $ladder_sorted[$calpeaks_count-1] -
					($cen-$cal_lane_peaks_sorted[$i][$calpeaks_count-1]) * 
						($ladder_sorted[$calpeaks_count-2]-$ladder_sorted[$calpeaks_count-1]) / 
							($cal_lane_peaks_sorted[$i][$calpeaks_count-1]-$cal_lane_peaks_sorted[$i][$calpeaks_count-2]);
			}
			else
			{#current cen between biggest and smallest, its between $l-1 and $l 
				$mass = $ladder_sorted[$l] + 
					($cal_lane_peaks_sorted[$i][$l]-$cen) * 
						($ladder_sorted[$l-1]-$ladder_sorted[$l]) / #difference in surronding ladder masses (corresponding to cal lane peaks)
							($cal_lane_peaks_sorted[$i][$l]-$cal_lane_peaks_sorted[$i][$l-1]); #difference in surrounding cal lane peaks (-)
			}
		}
		push @cal_mass, $mass;
	}
	
	#average together the calmasses, and save to arrays
	my $avg_mass=0;
	my $mass_err=0;
	for(my $j = 0; $j < scalar(@cal_mass); $j++)
	{#for each mass
		$avg_mass += $cal_mass[$j];
	}
	
	$avg_mass /= scalar(@cal_mass);
	$mass_err=std_dev(\@cal_mass) / ($num_calibration_lanes**.5);
	
	push @new_bands_cal_mass, $avg_mass;
	push @new_bands_cal_mass_error, $mass_err;	
}

## No amount data provided ## May implement this later... ##
#read in the amount calibration data
#my $amt_cal_mass_error = 5; #error allowed when looking for the amt. cal. band given the mass where it is to be found
##calibration data - each position corresponds to an amount calibration lane
#my @amt_cal_lane_sum; #sum for amount band in the amount calibration lane
#my @amt_cal_lane_mass; #mass associated with the band
#for(my $i = 0; $i < $num_amt_calibration_lanes; $i++)
#{
#	my $lane_num = $amt_calibration_lane_nums[$i];
#	my $amount = $calibration_lane_amts[$i];
#	my $cal_mass = $calibration_lane_masses[$i];
#	
#	if(open(IN, "$gel_directory/$gel_image_filename_root.lane-middle_cen_cal.$lane_num.txt"))
#	{
#		my $line = <IN>; #header
#		if($cal_mass > 0)
#		{#mass of quantity cal band given, find the mass closest to the input Mass
#			my $mass_found = 0; my $first = 1;
#			my $first_mass; my $first_sum;
#			while($line = <IN>)
#			{
#				chomp($line);
#				if ($line=~/^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)/)
#				{
#					my $cur_mass = $1;
#					if(abs($cur_mass - $cal_mass) < $amt_cal_mass_error)
#					{#this is the one to use!
#						$amt_cal_lane_mass[$i] = $cur_mass;
#						$amt_cal_lane_sum[$i] = $6;
#						$mass_found = 1;
#						last;
#					}
#					elsif($first)
#					{#remember largest band mass just in case we don't find a band at the mass given...
#					 #TODO: should probably return a warning/error in this case!!
#						$first_mass = $cur_mass;
#						$first_sum = $6;
#						$first = 0;
#					}
#				}
#				
#			}
#			if(!$mass_found)
#			{
#				#use the largest band
#				$amt_cal_lane_mass[$i] = $first_mass;
#				$amt_cal_lane_sum[$i] = $first_sum;
#			}
#			
#		}
#		else
#		{
#			#no mass given for the quantity calibration band, so get the largest one, i.e.
#			#first mass, sum (sorted by sum so we are getting the largest one) 
#			$line = <IN>; chomp($line);
#			if ($line=~/^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)/)
#			{
#				$amt_cal_lane_mass[$i] = $1;
#				$amt_cal_lane_sum[$i] = $6;
#			}
#		}
#		
#		close(IN);
#		
#		print LOG "amt_cal_lane_largest_sum_mass ($lane_num) = $amt_cal_lane_mass[$i]\n";
#		print LOG "amt_cal_lane_largest_sum ($lane_num) = $amt_cal_lane_sum[$i]\n";	
#	}
#	else
#	{
#		print LOG "Error: Could not open file: '$gel_directory/$gel_image_filename_root.lane-middle_cen_cal.$lane_num.txt'.\n";
#		return 0;
#	}
#}

#save results to new file, same format as band info file
my $outfile = $new_bands_file;
$outfile =~ s/\.[^\.]+$//;
$outfile .= '.mass_and_amount.txt';
#print "'$gel_directory/$outfile'\n";
if (open(OUT,">$gel_directory/$outfile"))
{
	print OUT "$header\tmass\terror\tamt\terror\n";
	for(my $j = 0; $j < scalar(@new_bands_cal_mass); $j++)
	{
		print OUT qq!$new_bands_lane_num[$j]\t$new_bands_y_pos[$j]\t$new_bands_top[$j]\t$new_bands_height[$j]\t$new_bands_cal_mass[$j]\t$new_bands_cal_mass_error[$j]\t0\t0\n!; 
	}
	close(OUT);
}
else
{
	print LOG qq!Error opening file: $gel_directory/$outfile.\n!;
	exit(1);
}

print LOG "DONE\n";
exit(0);
########################

sub std_dev
{#finds std dev of numbers in array
	my @numbers = @{$_[0]};
	
	my $mean = 0;
	foreach (@numbers)
	{
		$mean += $_;
	}
	$mean /= ($#numbers + 1);
	
    my $sd = 0;
    foreach (@numbers)
	{
		$sd += ($mean-$_)**2
	}
	$sd /= ($#numbers + 1);
    $sd = $sd**.5;
    
	return $sd;
	
}


