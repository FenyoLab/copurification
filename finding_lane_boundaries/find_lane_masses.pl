#!c:/perl/bin/perl.exe

#    find_lane_masses.pl - Finds the masses/amounts of the bands in the lanes given a gel image file name 
#    uses mass/amount calibration data from the input calibration file
#
#    Copyright (C) 2015  Sarah Keegan
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.lane_peaks_info
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Finds the masses/amounts of the bands in the lanes given a gel image file name 
# uses mass/amount calibration data from the input calibration file

#1) get_lane_peaks - finds the masses for each lane - cuts off edges (only uses middle 1/2 of lane)
#	- input: gel.lane.i.txt, gel.lane.i.png
#	- output: gel.lane-middle.i.png (can remove this?), gel.lane-middle.i.txt (also uses it), 
#                  gel.lane-middle_min.i.txt (can remove this?), gel.lane-middle_cen.i.txt (main result)
#        - ? do we need to use png?  can we go directly from txt to middle txt?  (png -> make more general)
#
#2) calc_mass_calibration_data - if it's a cal lane, calculates the mass calibration data given the ladder masses
#	- input: gel.lane-middle_cen.i.txt
#	- output: gel.lane-mass-cal.i.txt
#
#3) calibrate_mass
#	input: gel.lane-middle_cen.i.txt
#	output: gel.lane-middle_cen_cal.cal-lane-<mass-cal-lane>.i.txt (if > 1 mass cal lane, 1 file for each mass cal lane is produced)
#		OR gel.lane-middle_cen_cal.i.txt (if only 1 mass cal lane)
#
#4) average_calibrated_mass - only called if > 1 mass cal lane
#	input: gel.lane-middle_cen_cal.cal-lane-<mass-cal-lane>.i.txt
#	output: gel.lane-middle_cen_cal.i.txt
#
#5) calculate_amount_calibration_data <- add!
#	input: gel.lane-middle_cen_cal.<amt-cal-lane>.txt (<amt-cal-lane> is lane w/ largest amount if > 1 amount cal lane (only 1 amount cal lane currently supported)
#	output: (set variables in program)
#
#5) calibrate_amount
#	input: gel.lane-middle_cen_cal.i.txt
#	output: gel.lane-middle_cen_cal_sum_cal.i.txt
#
#---
#TO DO:
#
#use internal arrays to save data instead of all the files...

use lib "../lib";

use strict;
use warnings;
use diagnostics;
use Biochemists_Dream::Common;
use File::Copy;

sub numerically { $a <=> $b; }
sub numericallydesc { $b <=> $a; }
#open settings file and read in settings (imagemagick directory):
my $err = "";
if($err = read_settings()) 
{ exit(0); }

#program takes 4 arguments on the command line -
# (0) the gel image file directory
# (1) the gel image file root (no dir or extension)
# (2) number of lanes in the gel 
# (3) calibration lanes txt file (calibration.txt by default) - contains:
#     the number of mass calibration lanes 
#     the lane numbers of the mass calibration lanes (tab-separated)
#     the comma separated ladder masses (tab-separated)
#     the number of amout cal. lanes 
#     the lane numbers of the amt. cal lanes (tab-separated)
#     the amounts (tab-separated)
#     the mass to look for the amount cal band (tab-separated) - if mass is 0, then looks for largest band

#peak finding parameters
my $MIN_SUM_PERCENT = 0.05;
my $MIN_SUM_RAW = 0; #50;
my $CUTOFF_SUM_PERCENT = 0.01;
my $CUTOFF_RAW = 0; #7;

# whether to contrast stretch before peak finding - needed if ladder lane is not found correctly during peak finding
# empty string - no contrast stretch; 'n' = 1x cs, 'nn' == 2x cs (uses cs lane images cut out by find_lane_boundaries2)
my $CS_AMT = '';
 
my $END_BAND_PERCENT = 0.25;
my $MIN_BAND_SEP_PIXELS =  1;

my $MAX_PEAKS = 1000; #basically, not limiting number of peaks
			
my $gel_directory;
my $calibration_filename;
my $lanes;
my $gel_image_filename_root;

$gel_directory = "$ARGV[0]";
$gel_image_filename_root = "$ARGV[1]";
$lanes = "$ARGV[2]";
$calibration_filename = "$ARGV[3]";

open(LOG, ">$gel_directory/$gel_image_filename_root.find_lane_masses.log.txt") || die "Could not open log file ($gel_directory/$gel_image_filename_root.find_lane_masses.log.txt).\n";
print LOG "begin find lane masses\n";

my $alignment_gel;
my $cal_lane_alignment_gel;
my $do_alignment = 0;
if ($#ARGV > 3)
{
	$do_alignment = 1;
	$alignment_gel = $ARGV[4];
	$cal_lane_alignment_gel = $ARGV[5];
}

#####
system(qq!"$IMAGEMAGICK_DIR/convert" "$gel_directory/$gel_image_filename_root.tif" -contrast-stretch 1\%x1\% "$gel_directory/$gel_image_filename_root.n.tif"!);
#####
	
#read in the calibration information:
open(IN, "$gel_directory/$calibration_filename") || die "Error: Could not open calibration text file: '$gel_directory/$calibration_filename'.\n"; 

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
###########################################################################################################

#sort ladders for use in calibration functions
my @calibration_lane_sorted_ladders;
for(my $i = 0; $i < $num_calibration_lanes; $i++)
{
	@{$calibration_lane_sorted_ladders[$i]} = sort numericallydesc @{$calibration_lane_ladders[$i]};
}

my @lane_peaks; #2 d array, each pos. contains the set of "peaks" found for that lane
my @lane_peaks_info;
my @cal_lane_peaks_sorted; #2 d array, each pos. contains the set of sorted "peaks" found for the calibration lane (lane number is the lane number in the 
						   #corresponding position in the @calibration_lane_nums array
			   
#set peak finding parameters using 1st ladder lane
my $num_ladder_bands = $#{$calibration_lane_ladders[0]}+1;
get_lane_peaks($calibration_lane_nums[0]);
my $mult=1.0;
set_peak_params_manually(0,$mult);
get_lane_peaks($calibration_lane_nums[0]);
my $num_cal_peaks = calc_mass_calibration_data(0);
while($num_cal_peaks < $num_ladder_bands and $mult > 0)
{
	print LOG "Note: reducing peak params multiplier ($mult), since not enough peaks for ladder lane found ($num_cal_peaks < $num_ladder_bands).\n";
	$mult = $mult-0.10;
	set_peak_params_manually(0,$mult);
	
	get_lane_peaks($calibration_lane_nums[0]);
	$num_cal_peaks = calc_mass_calibration_data(0);
}

##### Another way to make sure ladder bands are detected - not used - above turned out to be enough - but leaving here in case need to use in the future #####
# this will contrast stretch until it can find the ladder bands #
# if($num_cal_peaks < $num_ladder_bands)
# {	
	# print LOG "Note: applying contrast-stretch 1, since not enough peaks for ladder lane found ($num_cal_peaks < $num_ladder_bands).\n";
	# $CS_AMT = 'n.';
	# get_lane_peaks($calibration_lane_nums[0]);
	# $num_cal_peaks = calc_mass_calibration_data(0);
	
	# if($num_cal_peaks < $num_ladder_bands)
	# {
		# print LOG "Note: applying contrast-stretch 2, since not enough peaks for ladder lane found ($num_cal_peaks < $num_ladder_bands).\n";
		# $CS_AMT = 'nn.';
		# get_lane_peaks($calibration_lane_nums[0]);
		# $num_cal_peaks = calc_mass_calibration_data(0);
		# if($num_cal_peaks < $num_ladder_bands)
		# {
			# print LOG "Error: not enough peaks found for ladder lane after 2 contrast stretches ($num_cal_peaks < $num_ladder_bands).\n";
		# }
	# }
	# set_peak_params_using_ladder(0);
# }
# else { print LOG "Note: no contrast stretch applied ($num_cal_peaks == $num_ladder_bands).\n"; }
######

for(my $i = 1; $i <= $lanes; $i++)
{
	get_lane_peaks($i);
	
	#if its a calibration lane, compare to ladder file
	my $cal_lane = 0; my $j;
	for($j = 0; $j < $num_calibration_lanes; $j++) { if($calibration_lane_nums[$j] == $i) { $cal_lane = 1; last; }  }
	
	if($cal_lane == 1) { calc_mass_calibration_data($j); }	
}

#calibrate the lane masses based on the calibration lane data...
for(my $i = 1; $i <= $lanes; $i++) { calibrate_mass($i); }

#next, average the calibrated masses for each lane
if($num_calibration_lanes > 1)
{
	for(my $i = 1; $i <= $lanes; $i++) { average_calibrated_mass($i); }
}

#amount calibration:
my $amt_cal_mass_error = 5; #error allowed when looking for the amt. cal. band given the mass where it is to be found

#calibration data - each position corresponds to an amount calibration lane
my @amt_cal_lane_sum; #sum for amount band in the amount calibration lane
my @amt_cal_lane_mass; #mass associated with the band

my $copy_file_root;
if($num_amt_calibration_lanes > 0)
{#do the amt calibration:
	$copy_file_root = "$gel_directory/$gel_image_filename_root.lane-middle_cen_cal_sum_cal";
	
	#calculate amount calibration standard for each amount cal lane
	for(my $i = 0; $i < $num_amt_calibration_lanes; $i++)
	{
		calculate_amount_calibration_data($i, $calibration_lane_amts[$i], $calibration_lane_masses[$i], $amt_calibration_lane_nums[$i]);
	}
	
	#calibrate amount for each lane
	for(my $i = 1; $i <= $lanes; $i++) { calibrate_amount($i); }
	
	#average the calibrated amounts for each lane:
	if($num_amt_calibration_lanes > 1)
	{
		for(my $i = 1; $i <= $lanes; $i++) { average_calibrated_amounts($i); }
	}
}
else { $copy_file_root = "$gel_directory/$gel_image_filename_root.lane-middle_cen_cal"; }

#set up output files with file names that can be used by 'Biochemists Dream' - get name format from Common.pm package
my $output_file = $LANE_OUTPUT_FILE_FORMAT;
$output_file =~ s/#root#/$gel_image_filename_root/;
for(my $i = 1; $i <= $lanes; $i++)
{#copy output file with new name:
	
	my $cur_output_file = $output_file;
	$cur_output_file =~ s/#i#/$i/;
	copy("$copy_file_root.$i.txt", "$gel_directory/$cur_output_file");
	
	#delete all intermediate files?!
}

if ($do_alignment)
{
	my $pixel_offset = calculate_lane_alignment_pixels($alignment_gel, $cal_lane_alignment_gel);
	$pixel_offset = int($pixel_offset);
	
	if ($pixel_offset != 0)
	{
		#output new lane images with pixels added/subtracted
		for(my $i=1; $i <= $lanes; $i++)
		{
			if ($pixel_offset > 0)
			{
				system(qq!"$IMAGEMAGICK_DIR/convert" "$gel_directory/$gel_image_filename_root.lane.$i.n.png" -background white -splice 0x$pixel_offset "$gel_directory/$gel_image_filename_root.lane.$i.n.a.png"!);
			}
			else
			{
				system(qq!"$IMAGEMAGICK_DIR/convert" "$gel_directory/$gel_image_filename_root.lane.$i.n.png" -chop 0x$pixel_offset "$gel_directory/$gel_image_filename_root.lane.$i.n.a.png"!);
		
			}
			
		}
	}
	
	
}

close (LOG);
########### subroutines #####################################################################################################################

sub calculate_amount_calibration_data
{
	my $array_pos = shift;
	my $amount = shift;
	my $cal_mass = shift;
	my $lane_num = shift;

	#input cal lane data for the cal lane w/ the largest 'amount'
	if(open(IN, "$gel_directory/$gel_image_filename_root.lane-middle_cen_cal.$lane_num.txt"))
	{
		$line = <IN>; #header
		if($cal_mass > 0)
		{#mass of quantity cal band given, find the mass closest to the input Mass
			my $mass_found = 0; my $first = 1;
			my $first_mass; my $first_sum;
			while($line = <IN>)
			{
				chomp($line);
				if ($line=~/^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)/)
				{
					my $cur_mass = $1;
					if(abs($cur_mass - $cal_mass) < $amt_cal_mass_error)
					{#this is the one to use!
						$amt_cal_lane_mass[$array_pos] = $cur_mass;
						$amt_cal_lane_sum[$array_pos] = $6;
						$mass_found = 1;
						last;
					}
					elsif($first)
					{#remember largest band mass just in case we don't find a band at the mass given...
					 #TODO: should probably return a warning/error in this case!!
						$first_mass = $cur_mass;
						$first_sum = $6;
						$first = 0;
					}
				}
				
			}
			if(!$mass_found)
			{
				#use the largest band
				$amt_cal_lane_mass[$array_pos] = $first_mass;
				$amt_cal_lane_sum[$array_pos] = $first_sum;
			}
			
		}
		else
		{
			#no mass given for the quantity calibration band, so get the largest one, i.e.
			#first mass, sum (sorted by sum so we are getting the largest one) 
			$line = <IN>; chomp($line);
			if ($line=~/^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)/)
			{
				$amt_cal_lane_mass[$array_pos] = $1;
				$amt_cal_lane_sum[$array_pos] = $6;
			}
		}
		
		close(IN);
		
		print LOG "amt_cal_lane_largest_sum_mass ($lane_num) = $amt_cal_lane_mass[$array_pos]\n";
		print LOG "amt_cal_lane_largest_sum ($lane_num) = $amt_cal_lane_sum[$array_pos]\n";	
	}
	else
	{
		print LOG "Error: Could not open file: '$gel_directory/$gel_image_filename_root.lane-middle_cen_cal.$lane_num.txt'.\n";
		return 0;
	}	
}

sub set_peak_params_manually
{
	my $cal_lane_i = shift;
	my $cutoff_multiplier = shift;
	
	my $lane_num = $calibration_lane_nums[$cal_lane_i];
	
	#get biggest peak - use it to set peak finding params
	$MIN_SUM_RAW = $lane_peaks_info[$lane_num][0][2] / 5; 
	$CUTOFF_RAW = $lane_peaks_info[$lane_num][0][1] / 12; 
	
	$CUTOFF_RAW = $CUTOFF_RAW * $cutoff_multiplier;
	$MIN_SUM_RAW = $MIN_SUM_RAW * $cutoff_multiplier;
}

##### OLD - BAD #####
sub set_peak_params_using_ladder
{#try this with gel1 - see what these values come out to be - we know what the correct values should be...
	my $lane_num = $calibration_lane_nums[0];
	
	#get biggest peak - use it to set peak finding params
	$MIN_SUM_RAW = $lane_peaks_info[$lane_num][0][2] / 5; 
	$CUTOFF_RAW = $lane_peaks_info[$lane_num][0][1] / 12; #16;
	
	#double check CUTOFF_RAW AND readjust if it will eliminate a ladder band
	my $i_stop = 0;
	my $num_ladder_bands = $#{$calibration_lane_ladders[0]}+1;
	my $i;
	for($i = 0; $i <= $#{$lane_peaks_info[$lane_num]}; $i++)
	{
		if ($lane_peaks_info[$lane_num][$i][1] < $CUTOFF_RAW)
		{
			$i_stop = 1;
			last;
		}
	}
	my $corrected = 0;
	if ($i_stop)
	{
		if ($i < $num_ladder_bands)
		{
			my $check_index = ($num_ladder_bands-$i) + ($i-1);
			while ($check_index > $#{$lane_peaks_info[$lane_num]}) { $check_index--; }
			if ($lane_peaks_info[$lane_num][$check_index][1] < $CUTOFF_RAW)
			{
				$CUTOFF_RAW = $lane_peaks_info[$lane_num][$check_index][1] * .75;
				$corrected = 1;
			}	
		}
	}
	
	if(open(OUT, ">$gel_directory/$gel_image_filename_root.peak_params.txt"))
	{
		print OUT "MIN_SUM_RAW = $MIN_SUM_RAW\n\nCUTOFF_RAW = $CUTOFF_RAW\n\nCUTOFF_RAW corrected = $corrected\n";
		close(OUT);
	}
}

sub find_max_intensity_x
{
	my $lane_num = shift;
	my $lane_width = shift;
	my $lane_height = shift;
	my $window_size = shift;
	
	#collapse the y values to get an average intensity for each x point
	my $geometry = $lane_width;
	$geometry .= "x1";
	$geometry .= "\!";
	system(qq!"$IMAGEMAGICK_DIR/convert" "$gel_directory/$gel_image_filename_root.lane.$lane_num.txt" -scale $geometry "$gel_directory/$gel_image_filename_root.lane.$lane_num.x.txt"!);
	
	if(!open(IN, "$gel_directory/$gel_image_filename_root.lane.$lane_num.x.txt"))
	{
		print LOG "Error: Could not open lane text file: '$gel_directory/$gel_image_filename_root.$lane_num.x.txt'.\n"; 
		return 0;
	}
	
	my $line=<IN>;
	my $max_sum=0;
	my $max_pos=0;
	my @intensity_array=();
	if ($line =~ /^# ImageMagick pixel enumeration: $lane_width,1,([0-9]+),\w+/)
	{
		my $max_intensity=$1;
		
		#read in the intensity information - smooth the data
		while($line=<IN>)
		{
			if ($line=~/^([0-9]+)\,0\:\s*\(\s*([0-9]+)\s*\,\s*([0-9]+)\s*\,\s*([0-9]+)\s*\)/ ||
			    $line=~/^([0-9]+)\,0\:\s*\(\s*([0-9]+)\s*\,\s*([0-9]+)\s*\,\s*([0-9]+)\s*\,\s*([0-9]+)\s*\)/)
			{
				my $k=$1;
				my $cur_intensity=$max_intensity-($2+$3+$4)/3; #average rgb values and subtract from max to reverse so black is highest (not white)
				$intensity_array[$k]=$cur_intensity;
			}
			else
			{
				print LOG "Gel $gel_image_filename_root, Lane $lane_num - error in line: $line\n";
			}
		}
		
		#try cumulative sum over sliding window - maybe this max will work
		for(my $pos_i=0; $pos_i<=($lane_width-$window_size); $pos_i++)
		{
			my $cur_sum=0;
			for(my $j=$pos_i; $j<($pos_i+$window_size); $j++)
			{
				$cur_sum += $intensity_array[$j]
			}
			if($cur_sum > $max_sum)
			{
				$max_sum = $cur_sum;
				$max_pos = $pos_i;
			}
		}
	}
	else
	{
		print LOG "Gel $gel_image_filename_root, Lane $lane_num - error in line: $line\n";
	}
	
	print LOG "Gel $gel_image_filename_root.$lane_num.x.txt: max intensity x pos = $max_pos, window=$window_size\n";
	return $max_pos;
	
}

sub get_lane_peaks
{#get the lane peaks for the lane number given in the argument to the function, and stores it in a file

	my $lane_num = shift;
	
	#clear out lane_peaks
	$lane_peaks[$lane_num] = ();
	$lane_peaks_info[$lane_num] = ();
	
	#open the lane file and extract the middle 1/2 of the lane (cut off 1/4 on both sides)
	
	if(!open(IN, "$gel_directory/$gel_image_filename_root.lane.$lane_num.txt"))
	{
		print LOG "Error: Could not open lane text file: '$gel_directory/$gel_image_filename_root.lane.$lane_num.txt'.\n"; 
		return 0;
	}
	
	my $line = <IN>;
	my $width; my $height;
	if($line =~ /^# ImageMagick pixel enumeration\: ([0-9]+),([0-9]+),([0-9]+),\w+/)
	{
		$width = $1;
		$height = $2;
	}
	else 
	{ 
		print LOG "Error: Could not read width/height from lane txt file: '$gel_directory/$gel_image_filename_root.lane.$lane_num.txt'.\n"; 
		close(IN);
		return 0;
	}
	close(IN);
	
	my $percent = 0.25; #0.40;  # for gel 1, 25 works.  30 does not work.
	my $offset = $width*$percent; 
	$offset =~ s/\..*$//;
	my $x_pos = find_max_intensity_x($lane_num, $width, $height, $width-(2*$offset));
	
	my $geometry = $width-(2*$offset); 
	$geometry =~s /\..*$//;
	$geometry .= "x";
	$geometry .= "$height";
	$geometry .= "+";
	
	$geometry .= "$x_pos";
	#$geometry .= "$offset";
	
	$geometry .= "+0";
	
	#system(qq!"$IMAGEMAGICK_DIR/convert" "$gel_directory/$gel_image_filename_root.lane.$lane_num.png" -crop $geometry "$gel_directory/$gel_image_filename_root.lane-middle.$lane_num.png"!);
	#system(qq!"$IMAGEMAGICK_DIR/convert" "$gel_directory/$gel_image_filename_root.lane.$lane_num.n.png" -crop $geometry "$gel_directory/$gel_image_filename_root.lane-middle.$lane_num.n.png"!);
	
	system(qq!"$IMAGEMAGICK_DIR/convert" "$gel_directory/$gel_image_filename_root.lane.$lane_num.! . $CS_AMT . qq!png" -crop $geometry "$gel_directory/$gel_image_filename_root.lane-middle.$lane_num.! . $CS_AMT . qq!png"!);
	#print LOG qq!"$IMAGEMAGICK_DIR/convert" "$gel_directory/$gel_image_filename_root.lane.$lane_num.! . $CS_AMT . qq!png" -crop $geometry "$gel_directory/$gel_image_filename_root.lane-middle.$lane_num.! . $CS_AMT . qq!png"!;
	
	#collapse the x values to get an average intensity for each y point
	$geometry = "1x";
	$geometry .= "$height";
	$geometry .= "\!";
	system(qq!"$IMAGEMAGICK_DIR/convert" "$gel_directory/$gel_image_filename_root.lane-middle.$lane_num.! . $CS_AMT . qq!png" -scale $geometry "$gel_directory/$gel_image_filename_root.lane-middle.$lane_num.! . $CS_AMT . qq!txt"!);
	#print LOG qq!"$IMAGEMAGICK_DIR/convert" "$gel_directory/$gel_image_filename_root.lane-middle.$lane_num.! . $CS_AMT . qq!png" -scale $geometry "$gel_directory/$gel_image_filename_root.lane-middle.$lane_num.! . $CS_AMT . qq!txt"!;
	
	if(!open(IN, "$gel_directory/$gel_image_filename_root.lane-middle.$lane_num." . $CS_AMT . "txt"))
	{
		print LOG "Error: Could not open lane text file: '$gel_directory/$gel_image_filename_root.lane-middle.$lane_num." . $CS_AMT . "txt'.\n"; 
		return 0;
	}
	
	$line=<IN>;
	if ($line =~ /^# ImageMagick pixel enumeration: 1,$height,([0-9]+),\w+/)
	{
		my $max_intensity=$1;
		my $k=0;
		my @y=(); #array y stores the intensity at each point y from 0 to height
		my @y_min=(); #this array stores min. intensity of each of the 20 equal sections that will divide up the lane (smoothing)
		
		#read in the intensity information - smooth the data
		while($line=<IN>)
		{
			if ($line=~/^0\,([0-9]+)\:\s*\(\s*([0-9]+)\s*\,\s*([0-9]+)\s*\,\s*([0-9]+)\s*\)/ ||
			    $line=~/^0\,([0-9]+)\:\s*\(\s*([0-9]+)\s*\,\s*([0-9]+)\s*\,\s*([0-9]+)\s*\,\s*([0-9]+)\s*\)/)
			{
				$k=$1;
				$y[$k]=$max_intensity-($2+$3+$4)/3; #average rgb values and subtract from max to reverse so black is highest (not white)
				
				#divide lane into 20 bins and find minimum in each part 
				my $k_=20*$k/$height;
				$k_=~s/\..*$//;
				if ($y_min[$k_]!~/\w/ or ($y[$k]<$y_min[$k_] and $y[$k] != 0)) { $y_min[$k_]=$y[$k]; } #added and $y[$k] != 0 ***
			}
			else
			{
				print LOG "Gel $gel_image_filename_root, Lane $lane_num - error in line: $line\n";
			}
		}
		
		my @y_=(); #adjust each y_min - use y_min[k_], y_min[k_-1], y_min[k_+1] to produce y_
		for($k=0;$k<$height;$k++)
		{
			#fill @y_
			my $k_=int(20*$k/$height); #$k_ is the box num. 1-20
			$y_[$k]=$y_min[$k_];
			
			my $y__=0;
			my $y__count=0;
			if ($k_<20-1) 
			{#if its not the last
				$y__ += ($y_min[$k_+1]-$y_min[$k_])*(20*$k/$height-$k_) ;
				$y__count++;
			}
			if ($k_>0) 
			{#if its not the first
				$y__ += ($y_min[$k_-1]-$y_min[$k_])*(1 - (20*$k/$height-$k_)) ;
				$y__count++;
			}
			if ($y__count>0) { $y_[$k]+= $y__/$y__count; }
		}
		
		#average every 5 points
		$y_[0]=($y_[0]+$y_[1]+$y_[2])/3;
		$y_[1]=($y_[0]+$y_[1]+$y_[2]+$y_[3])/4;
		for($k=2;$k<$height-2;$k++)
		{
			$y_[$k]=($y_[$k-2]+$y_[$k-1]+$y_[$k]+$y_[$k+1]+$y_[$k+2])/5;
		}
		$y_[$height-2]=($y_[$height-2-2]+$y_[$height-2-1]+$y_[$height-2]+$y_[$height-1])/4;
		$y_[$height-1]=($y_[$height-1-2]+$y_[$height-1-1]+$y_[$height-1])/3;
		
		#subtracting noise
		my @y__=();
		if (open(OUT, ">$gel_directory/$gel_image_filename_root.lane-middle_min.$lane_num.txt"))
		{
			for($k=0;$k<$height;$k++)
			{
				$y__[$k]=$y[$k]-$y_[$k]; 
				if ($y__[$k]<0) { $y__[$k]=0; }
				print OUT qq!$k\t$y[$k]\t$y_[$k]\t$y__[$k]\n!;
			}
			close(OUT);
		}
		
		#############################################
		# sum intensity values of whole lane, over each y-value
		if(!open(IN_SUM, "$gel_directory/$gel_image_filename_root.lane.$lane_num.txt"))
		{
			print LOG "Error: Could not open lane text file: '$gel_directory/$gel_image_filename_root.lane.$lane_num.txt'.\n"; 
			return 0;
		}
		my @gel;
		$line=<IN_SUM>;
		if($line=~/^# ImageMagick pixel enumeration\: ([0-9]+),$height,([0-9]+),\w+/)
		{
			$width = $1;
			my $max_intensity=$2;
			
			#read in the intensity information 
			while($line=<IN_SUM>)
			{
				if($line=~/^([0-9]+),([0-9]+):\s*\(\s*([0-9]+),\s*([0-9]+),\s*([0-9]+)\)/ ||
				   $line=~/^([0-9]+),([0-9]+):\s*\(\s*([0-9]+),\s*([0-9]+),\s*([0-9]+),\s*([0-9]+)\)/)
				{#read in the rgb data for each lane in the gel into the 2d array @gel
					
					$gel[$1][$2] = $max_intensity-($3+$4+$5)/3;
				}
				else
				{
					print LOG "Gel $gel_image_filename_root, Lane $lane_num - error in line: $line\n";
				}
			}
		}
		close(IN_SUM);
		
		#sum intensity over all x's for each y, subtracting noise calculated above (y_)
		my @y_lane_sum;
		for(my $y_val = 0; $y_val < $height; $y_val++)
		{
			$y_lane_sum[$y_val] = 0;
			for(my $i = 0; $i < $width; $i++)
			{
				# *** removed subtraction of noise, since it is calculated from the contrast-stretched lane image ****
				# TODO: get a noise value for the non-constrast-stretched lane image, instead
				#my $diff = $gel[$i][$y_val] - $y_[$y_val];
				#if ($diff > 0) { $y_lane_sum[$y_val] += $diff; }
				
				if($CS_AMT eq '')
				{
					my $diff = $gel[$i][$y_val] - $y_[$y_val];
					if ($diff > 0) { $y_lane_sum[$y_val] += $diff; }
				}
				else
				{
					$y_lane_sum[$y_val] += $gel[$i][$y_val];
				}
				
			}
		}
		############################################
		
		
		#calculate the centroids and output the processed data to file
		if (open(OUT,">$gel_directory/$gel_image_filename_root.lane-middle_cen.$lane_num.txt"))
		{
			print OUT qq!pixel\tmin\tmax\tcen\tsum\tmax\n!;
			my @max=();
			my @sum=();
			my @cen=();
			my @to_sort=();
			for(my $k=1;$k<$height-1;$k++)
			{
				for(my $l=$k-1;$l<=$k+1;$l++) 
				{ 
					$sum[$k]+=$y__[$l]; 
					$cen[$k]+=$l*$y__[$l];
					if ($max[$k]!~/\w/ or $max[$k]<$y__[$l]) { $max[$k]=$y__[$l]; }
				}
				$to_sort[$k]=qq!$sum[$k]#$k!;
			}
			my @sorted = sort numericallydesc @to_sort; # TODO sort is throwing a warning since we have the # at the end...!  figure out/fix!
			my @done=();
			my $peaks_count = 0;
			
			if (open(OUT_SUMDATA,">$gel_directory/$gel_image_filename_root.lane-sum_data.$lane_num.txt"))
			{
				for(my $k=1;$k<$height-1;$k++)
				{
					print OUT_SUMDATA "$to_sort[$k]\n";
				}
				print OUT_SUMDATA "\n\n\n\n\n";
				for(my $k=1;$k<$height-1;$k++)
				{
					print OUT_SUMDATA "$sorted[$k]\n";
				}
				
				close(OUT_SUMDATA);		
			}
			my $cutoff_sum = $CUTOFF_SUM_PERCENT * $sorted[0];
			my $min_sum = $MIN_SUM_PERCENT * $sorted[0];
			for(my $l=0,my $ll=0;$l<=$#sorted and $ll<$MAX_PEAKS;$l++)
			{
				if ($sorted[$l]=~/^([^#]+)#([^#]+)$/)
				{ 
					#no output when sum is less than 1% of highest sum
					my $sum = $1;
					my $k=$2;
					
					if ($done[$k]!~/\w/)
					{
						
						#NEW PART
						my $new_k1 = -1; 
						for(my $m=$k-1;$m>1 && $y__[$m+1]<$y__[$m];$m--) { $new_k1=$m; }
						my $new_k2 = -1;
						for(my $m=$k+1;$m<($height-2) && $y__[$m-1]<$y__[$m];$m++) { $new_k2=$m; }
						my $new_k = $new_k1 > $new_k2 ? $new_k1 : $new_k2;
						if ($new_k != -1)
						{
							$k = $new_k;
							$sum = $sum[$k];
						}
						
						my $k_min = $k; my $k_max = $k;
						if($sum >= $cutoff_sum && $y__[$k] >= $CUTOFF_RAW)
						{
							if($sum < $min_sum || $sum < $MIN_SUM_RAW) #{ last; }
							{#if there is a large enough diff between this pixel and the 2 around it, it will still be distinguishable
							 #even at low intensity
								my $go_next = 0;
								
								#check 3 pixels
								my $k_limit_lower = $y__[0] == 0 ? 2 : 1;
								my $k_limit_upper = $y__[$height-1] == 0 ? $height-3 : $height-2;
								if ( ($k<=$k_limit_lower || ($y__[$k]-$y__[$k-1] > .2*$y__[$k])) || ($k>=$k_limit_upper || ($y__[$k]-$y__[$k+1] > .2*$y__[$k])) )
								{
									if ($k<=$k_limit_lower && ($y__[$k]-$y__[$k+1] <= .2*$y__[$k])) { $go_next = 1; }
									if ($k>=$k_limit_upper && ($y__[$k]-$y__[$k-1] <= .2*$y__[$k])) { $go_next = 1; }
								}
								else { $go_next = 1; }
								
								#check 5 pixels
								if ($go_next)
								{
									if ( ($k<=$k_limit_lower+1 || ($y__[$k]-$y__[$k-2] > .5*$y__[$k])) || ($k>=$k_limit_upper-1 || ($y__[$k]-$y__[$k+2] > .5*$y__[$k])) )
									{# or maybe .6 ?
										if ($k<=$k_limit_lower+1 && ($y__[$k]-$y__[$k+2] <= .5*$y__[$k])) { next; }
										if ($k>=$k_limit_upper-1 && ($y__[$k]-$y__[$k-2] <= .5*$y__[$k])) { next; }
									}
									else { next; }
								}
								
								
							}
							#lower threshold and take 30% of $k +/- 2 ?
							
							if ($done[$k]!~/\w/)
							{
							## END NEW PART	  #$m>=0
								
								for(my $m=$k;$m>=0 && ($y__[$m]>$END_BAND_PERCENT*$y__[$k] && ($m == 0 || $y__[$m]>=$y__[$m-1]));$m--) 
								{ $k_min=$m; }
								for(my $m=$k;$m<=($height-1) && ($y__[$m]>$END_BAND_PERCENT*$y__[$k] && ($m == ($height-1) || $y__[$m]>=$y__[$m+1]));$m++) 
								{ $k_max=$m; }
									  #$m<$height						     
								
								if (($k_max - $k_min)+1 >= 3)
								{#must be atleast 3 pixels wide for a band
									my $done=0;
									for(my $m=$k_min;$m<=$k_max;$m++) { if ($done[$m]=~/\w/) { $done=1; } }
									if ($done==0)
									{
										my $amount_sum; #
										for(my $m=$k_min;$m<=$k_max;$m++) { $amount_sum += $y_lane_sum[$m]; } #
										#for(my $m=$k-2*($k-$k_min);$m<=$k+2*($k_max-$k);$m++) { if ($m>=0) { $done[$m]=1; } }
										for(my $m=$k_min-$MIN_BAND_SEP_PIXELS;$m<=$k_max+$MIN_BAND_SEP_PIXELS;$m++) { if ($m>=0) { $done[$m]=1; } }
										$cen[$k]/=$sum[$k];
										
										$lane_peaks[$lane_num][$peaks_count] = $cen[$k];
										$lane_peaks_info[$lane_num][$peaks_count] = [$k, $y__[$k], $sum[$k]];
										
										#print OUT qq!$k\t$k_min\t$k_max\t$lane_peaks[$lane_num][$peaks_count]\t$sum[$k]\t$max[$k]\n!;
										#print OUT qq!$k\t$k_min\t$k_max\t$lane_peaks[$lane_num][$peaks_count]\t$amount_sum\t$max[$k]\n!; 
										print OUT qq!$k\t$k_min\t$k_max\t$lane_peaks[$lane_num][$peaks_count]\t$amount_sum\t0\n!; 
										
										$peaks_count++;
										$ll++;
									}
								}
							}
						}
					}
				}
			}
			close(OUT);
		}
	}
	else { print LOG qq!Error parsing $gel_directory/$gel_image_filename_root.lane-middle.$lane_num.txt: $line\n!; }
	close(IN);
}

# sub calc_mass_calibration_data 
# {#compares the ladder information to the intensity information for given calibration lane (arg 1)
	# my $cal_array_pos = shift;
	# my $lane_num = $calibration_lane_nums[$cal_array_pos];
	
	# my @ladder_sorted = @{$calibration_lane_sorted_ladders[$cal_array_pos]};
	
	# #match up ladder masses to peaks
	# my @calpeaks;
	# for(my $i = 0; $i <= $#ladder_sorted && $i <= $#{$lane_peaks[$lane_num]}; $i++) 
	# { 
		
		# $calpeaks[$cal_i] = $lane_peaks[$lane_num][$i];
			
	# }
	# my @calpeaks_sorted = sort numerically @calpeaks;
	# for(my $i = 0; $i < scalar(@calpeaks_sorted); $i++) 
	# { 
		# $cal_lane_peaks_sorted[$cal_array_pos][$i] = $calpeaks_sorted[$i]; 
	# }
	# my $peaks_count = $#{$cal_lane_peaks_sorted[$cal_array_pos]}+1;
	
	# #print ladder masses/peaks to file
	# if (open(OUT,">$gel_directory/$gel_image_filename_root.lane-mass-cal.$lane_num.txt"))
	# {
		# print OUT qq!mass\tpixel\n!;
		# for(my $l=0;$l<$peaks_count;$l++)
		# {
			# print OUT qq!$ladder_sorted[$l]\t$cal_lane_peaks_sorted[$cal_array_pos][$l]\n!;
		# }
		# close(OUT);
	# }
	# else { print LOG qq!Error opening file $gel_directory/$gel_image_filename_root.lane-mass-cal.$lane_num.txt.\n!; }
	
# }

sub calc_mass_calibration_data
{
	my $cal_array_pos = shift;
	my $lane_num = $calibration_lane_nums[$cal_array_pos];
	
	my @ladder_sorted = @{$calibration_lane_sorted_ladders[$cal_array_pos]};
	
	#open the lane file and extract the height of the lane
	if(!open(IN, "$gel_directory/$gel_image_filename_root.lane.$lane_num.txt"))
	{
		print LOG "Error: Could not open lane text file: '$gel_directory/$gel_image_filename_root.lane.$lane_num.txt'.\n"; 
		return 0;
	}
	
	my $line = <IN>;
	my $width; my $height;
	if($line =~ /^# ImageMagick pixel enumeration\: ([0-9]+),([0-9]+),([0-9]+),\w+/)
	{
		$width = $1;
		$height = $2;
	}
	else 
	{ 
		print LOG "Error: Could not read width/height from lane txt file: '$gel_directory/$gel_image_filename_root.lane.$lane_num.txt'.\n"; 
		close(IN);
		return 0;
	}
	close(IN);
	
	my @calpeaks;
	
	my @cur_lane_peaks = sort numerically @{$lane_peaks[$lane_num]};
	my $cal_i=0;
	my $min_diff = (10/300)*$height; # 3% of 300 pixels - 10 pixels or more separation from the previous marker lane or its not a marker lane
	
	for(my $i = 0; $cal_i <= $#ladder_sorted && $i <= $#cur_lane_peaks; $i++) 
	{ 
		if(($i==0) or (abs($cur_lane_peaks[$i] - $cur_lane_peaks[$i-1]) >= $min_diff))
		{ # TODO: instead of using first peak encountered, use the one that has a darker band!
			$calpeaks[$cal_i] = $cur_lane_peaks[$i];
			$cal_i++;
		}
	}
	
	my @calpeaks_sorted = sort numerically @calpeaks;
	for(my $i = 0; $i < scalar(@calpeaks_sorted); $i++) { $cal_lane_peaks_sorted[$cal_array_pos][$i] = $calpeaks_sorted[$i]; }
	my $peaks_count = $#{$cal_lane_peaks_sorted[$cal_array_pos]}+1;
	
	#print ladder masses/peaks to file
	if (open(OUT,">$gel_directory/$gel_image_filename_root.lane-mass-cal.$lane_num.txt"))
	{
		print OUT qq!mass\tpixel\n!;
		for(my $l=0;$l<$peaks_count;$l++)
		{
			print OUT qq!$ladder_sorted[$l]\t$cal_lane_peaks_sorted[$cal_array_pos][$l]\n!;
		}
		close(OUT);
	}
	else { print LOG qq!Error opening file $gel_directory/$gel_image_filename_root.lane-mass-cal.$lane_num.txt.\n!; }
	
	return $peaks_count;
}
			  
sub calibrate_amount
{ # calibrates the lane amount in the given lane based on the amount calibration information for each calibration lane
  # the lane amount is the 'sum' from the get_lane_peaks
	my $lane_num = shift;
	
	my $infile_name = "$gel_directory/$gel_image_filename_root.lane-middle_cen_cal.$lane_num.txt";
	
	if (open(IN,"$infile_name"))
	{#read in line, get sum, calibrate and print as 'intensity' column to output file
		
		for(my $i = 0; $i < $num_amt_calibration_lanes; $i++) 
		{
			my $outfile_name;
			if($num_amt_calibration_lanes > 1) 
			{ $outfile_name = "$gel_directory/$gel_image_filename_root.lane-middle_cen_cal_sum_cal.cal-lane-$amt_calibration_lane_nums[$i].$lane_num.txt"; }
			else
			{ $outfile_name = "$gel_directory/$gel_image_filename_root.lane-middle_cen_cal_sum_cal.$lane_num.txt"; }
			
			if (open(OUT,">$outfile_name"))
			{
				my $line=<IN>; chomp($line);
				print OUT qq!$line\tamount\n!;
					
				while($line=<IN>)
				{
					chomp($line);
					if ($line=~/^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)/)
					{
						my $mass = $1;
						my $sum = $6;
						my $amount = $sum * ($calibration_lane_amts[$i] / $amt_cal_lane_sum[$i]) * ($amt_cal_lane_mass[$i] / $mass);	
						print OUT "$line\t$amount\n";
					}
				}
				close(OUT);
				seek IN, 0, 0; 
			}
			else { print LOG qq!Error opening file: $outfile_name.\n!; }
		}
		close(IN);
	} else { print LOG qq!Error reading file: $infile_name.\n!; }
}

sub calibrate_mass
{ #  calibrates the peaks in the given lane (arg. to function) based on the mass calibration information for each calibration lane
	my $lane_num = shift; 
	
	for(my $i = 0; $i < $num_calibration_lanes; $i++) 
	{
		my $cal_lane_num = $calibration_lane_nums[$i]; 
		my $calpeaks_count = $#{$cal_lane_peaks_sorted[$i]}+1;
		my @ladder_sorted = @{$calibration_lane_sorted_ladders[$i]};
		
		if (open(IN,"$gel_directory/$gel_image_filename_root.lane-middle_cen.$lane_num.txt"))
		{
			my $outfile_name;
			if($num_calibration_lanes > 1) 
			{ $outfile_name = "$gel_directory/$gel_image_filename_root.lane-middle_cen_cal.cal-lane-$cal_lane_num.$lane_num.txt"; }
			else
			{ $outfile_name = "$gel_directory/$gel_image_filename_root.lane-middle_cen_cal.$lane_num.txt"; }
			if (open(OUT,">$outfile_name"))
			{
				my $line=<IN>;
				print OUT qq!mass\t$line!;
				my $peaks_count = 0; 
				while($line=<IN>)
				{
					if ($line=~/^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t/)
					{
						my $cen = $lane_peaks[$lane_num][$peaks_count++];
						my $mass=0;
						my $l;
						
						#start at smallest pixel, stop when cen <= current peak (l is the index of smallest peak bigger than current cen
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
						print OUT qq!$mass\t$line!;
						
					}
				}
				close(OUT);
			} else { print LOG qq!Error opening file: $outfile_name.\n!; }
			close(IN);
		} else { print LOG qq!Error reading file: $gel_directory/$gel_image_filename_root.lane-middle_cen.$lane_num.txt.\n!; }
	}
}

sub average_calibrated_amounts
{#  averages all (calibrated) lane amounts for a particular lane (arg to function) over all calibrations
	my $lane_num = shift;
	my @lane_amounts;
	my @lane_avg_amounts;
	my @lane_amt_error;
	my @lane_line; 
	
	#for each calibration lane, read in lane amounts
	my $amt_count; my $header;
	for(my $i = 0; $i < $num_amt_calibration_lanes; $i++) 
	{
		my $cal_lane_num = $amt_calibration_lane_nums[$i]; 
		if (open(IN,"$gel_directory/$gel_image_filename_root.lane-middle_cen_cal_sum_cal.cal-lane-$cal_lane_num.$lane_num.txt"))
		{
			$header=<IN>; chomp($header);
			my $line;
			$amt_count = 0;
			while($line=<IN>)
			{
				chomp($line);
				if ($num_calibration_lanes > 1)
				{
					if ($line=~/^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$/)
					{
						$lane_amounts[$i][$amt_count] = $9;
						$line =~ s/\t([^\t]+)$//; #the rest of the line should be the same for each file
						$lane_line[$amt_count] = $line;
						$amt_count++;
					}	
				}
				else
				{
					if ($line=~/^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$/)
					{
						$lane_amounts[$i][$amt_count] = $8;
						$line =~ s/\t([^\t]+)$//; #the rest of the line should be the same for each file
						$lane_line[$amt_count] = $line;
						$amt_count++;
					}
					
				}
					
			}
			close(IN);
		} else { print LOG qq!Error reading file: $gel_directory/$gel_image_filename_root.lane-middle_cen_cal_sum_cal.cal-lane-$cal_lane_num.$lane_num.txt.\n!; }	
	}
	
	#average lane amounts, compute error -> the biggest difference if > 2 cal lanes?
	for(my $j = 0; $j < $amt_count; $j++)
	{#for each amount for the lane
		$lane_avg_amounts[$j] = 0;
		my @cur_amounts;
		for(my $i = 0; $i < $num_amt_calibration_lanes; $i++) 
		{#add in all the calibrated masses
			$lane_avg_amounts[$j] += $lane_amounts[$i][$j];
			push @cur_amounts, $lane_amounts[$i][$j];
		}
		$lane_avg_amounts[$j] /= $num_amt_calibration_lanes;
		
		#calculate std error:
		$lane_amt_error[$j] = std_dev(\@cur_amounts) / ($num_amt_calibration_lanes**.5);
	}
	
	#print out results to the file
	if (open(OUT,">$gel_directory/$gel_image_filename_root.lane-middle_cen_cal_sum_cal.$lane_num.txt"))
	{
		print OUT "$header\tamount error\n";
		for(my $j = 0; $j < $amt_count; $j++)
		{#for each amt for the lane
			print OUT "$lane_line[$j]\t$lane_avg_amounts[$j]\t$lane_amt_error[$j]\n"; 
		}
		close(OUT);
	}
	else { print LOG qq!Error opening file: $gel_directory/$gel_image_filename_root.lane-middle_cen_cal_sum_cal.$lane_num.txt.\n!; }	
}

sub average_calibrated_mass
{#  averages all (calibrated) lane masses for a particular lane (arg to function) over all calibrations

	my $lane_num = shift;
	my @lane_masses; #2d array, each array pos is an array of masses for the calibration lane $i
	my @lane_avg_masses; #array contains the average mass over all calibration lanes
	my @lane_mass_error;#array contains the mass error based on all calibration lanes
	my @lane_line; #array contains the band details from the file, its the same for each calibration (only mass changes)
		       #so only store info from the first file
	
	#for each calibration lane
	#read in lane masses, sums
	my $mass_count; my $header;
	for(my $i = 0; $i < $num_calibration_lanes; $i++) 
	{
		my $cal_lane_num = $calibration_lane_nums[$i]; 
		
		if (open(IN,"$gel_directory/$gel_image_filename_root.lane-middle_cen_cal.cal-lane-$cal_lane_num.$lane_num.txt"))
		{
			$header=<IN>; chomp($header);
			my $line;
			$mass_count = 0;
			while($line=<IN>)
			{
				chomp($line);
				if ($line=~/^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$/)
				{
					$lane_masses[$i][$mass_count] = $1;
					$line =~ s/^([^\t]+)\t//; #the rest of the line should be the same for each file
					$lane_line[$mass_count] = $line;
					$mass_count++;
				}
			}
			close(IN);
		} else { print LOG qq!Error reading file: $gel_directory/$gel_image_filename_root.lane-middle_cen_cal.cal-lane-$cal_lane_num.$lane_num.txt.\n!; }	
	}
	
	#average lane masses, compute error -> the biggest difference if > 2 cal lanes?
	for(my $j = 0; $j < $mass_count; $j++)
	{#for each mass for the lane
		$lane_avg_masses[$j] = 0;
		my @cur_masses;
		for(my $i = 0; $i < $num_calibration_lanes; $i++) 
		{#add in all the calibrated masses
			$lane_avg_masses[$j] += $lane_masses[$i][$j];
			push @cur_masses, $lane_masses[$i][$j];
		}
		$lane_avg_masses[$j] /= $num_calibration_lanes;
		
		#calculate std error:
		$lane_mass_error[$j] = std_dev(\@cur_masses) / ($num_calibration_lanes**.5);
	}
	
	#print out results to the file
	if (open(OUT,">$gel_directory/$gel_image_filename_root.lane-middle_cen_cal.$lane_num.txt"))
	{
		print OUT "$header\tmass error\n";
		for(my $j = 0; $j < $mass_count; $j++)
		{#for each mass for the lane
			print OUT qq!$lane_avg_masses[$j]\t$lane_line[$j]\t$lane_mass_error[$j]\n!; 
		}
		close(OUT);
	}
	else { print LOG qq!Error opening file: $gel_directory/$gel_image_filename_root.lane-middle_cen_cal.$lane_num.txt.\n!; }	
}

sub calculate_lane_alignment_pixels
{
	my $gel_file_name = shift;
	my $ladder_lane_num = shift;
	
	#get ladder list for alignment gel:
	if (open(IN,"$gel_directory/$gel_file_name.lane-mass-cal.$ladder_lane_num.txt"))
	{
		my $line=<IN>;
		while ($line=<IN>) 
		{
			if ($line=~/^([^\t]+)\t([^\t]+)/)
			{
				my $mass = $1;
				my $pixel = $2;
				
				for(my $i=0; $i<=$#{$cal_lane_peaks_sorted[0]};$i++)
				{
					my $cur_pixel = $cal_lane_peaks_sorted[0][$i];
					my $cur_mass = $calibration_lane_sorted_ladders[0][$i];
					if (abs($mass-$cur_mass)<1)
					{
						#found matching ladder bands, look at pixel difference
						my $diff = $pixel-$cur_pixel; #this is what we add/subtract to align this gel
						if (open(OUT,">>$gel_directory/alignment.txt"))
						{
							print OUT "$gel_image_filename_root\t$diff\n";
						}
						close(OUT);
						close(IN);
						return $diff;
					}
				}
			}
		}
		close(IN);
	}
	return 0;
}
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
        print $sd;
	return $sd;
	
}
 
