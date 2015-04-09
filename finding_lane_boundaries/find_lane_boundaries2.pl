#!c:/perl/bin/perl.exe
 
#    find_lane_boundaries2.pl - Finds lane boundaries in the images.
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

use lib "../lib";

use warnings;
use strict;
use Math::Trig;
use File::Copy;
use Biochemists_Dream::Common;

my %im_rot_angles = (-6 => -2, -5 => -1.75, -4 => -1.5, -3 => -1.25, -2 => -1, -1 => -0.75, 0 => 0, 1 => 0.75, 2 => 1, 3 => 1.25, 4 => 1.5, 5 => 1.75, 6 => 2); 
my $i_range = 6;

my $num_lanes; 
my $gel_txt_file;

if ($#ARGV == 1)
{ $gel_txt_file = $ARGV[0]; $num_lanes = $ARGV[1]; }
else { die "Wrong number of arguments...\n"; }

my $gel_image_file_root = $gel_txt_file;
$gel_image_file_root =~ s/.txt$//;

my $n_gel_txt_file = $gel_txt_file;
$n_gel_txt_file =~ s/.txt$/-n.txt/;
my $nn_gel_txt_file = $gel_txt_file;
$nn_gel_txt_file =~ s/.txt$/-nn.txt/;

#open settings file and read in settings (imagemagick directory):
my $err = "";
if($err = read_settings()) { die "Could not read settings file.\n"; }

open(IN, $gel_txt_file) || die "Could not input text file ($gel_txt_file).\n";

#open log file
open(LOG, ">$gel_image_file_root.log.txt") || die "Could not log file ($gel_image_file_root.log.txt).\n";

#read in the lines of the txt file (the image data)
my $line; my $x_max; my $y_max; my $color_max; my @gel;
while ($line=<IN>)
{ 
	if($line=~/^# ImageMagick pixel enumeration\: ([0-9]+),([0-9]+),([0-9]+),(s?rgb|graya?)/)
	{#the first line of the file, with the # pixels in x, y and max value for rgb data
		$x_max=$1; 
		$y_max=$2;
		$color_max=$3;
	}
	elsif($line=~/^([0-9]+),([0-9]+):\s\(\s*([0-9]+),\s*([0-9]+),\s*([0-9]+)[,\)]/)
	{#read in the rgb data for each lane in the gel into the 2d array @gel
                
                my $color = $color_max-($3+$4+$5)/3;
                $gel[$1][$2] = $color;
	}
	else { print LOG "Error reading line: '$line'\n"; }
}
close(IN);

my $ave_lane_width = $x_max/$num_lanes;

#these values work best with all the gel images we have tested with so far...
my $min_lane_width = int($ave_lane_width*.85); # = 20;
my $max_lane_width = int($ave_lane_width*1.25); # = 30;

my @min_intensity_sum;
my @min_intensity_sum_i;

#(1) sum intensities for the line from (x, 0) to (x + i, y_max) where i ranges from 0 to i_max
#    and x ranges from 0 to x_max (x_max = width of the image, y_max = length of the image)
for(my $x = 0; $x < $x_max; $x++)
{
    my $first_sum = 1;
    for(my $i = -$i_range; $i <= $i_range; $i++)
    {#sum intensities for the line from (x, 0) to (x + i, y_max) and store min. intensity found
     #for each x, over the i-range ($min_intensity_sum[$x])
        my $intensity_sum = 0; my $skipped_line = 0;
        my $inv_slope = $i / $y_max; 
        for(my $y = 0; $y < $y_max; $y++)
        {
            my $cur_x = $inv_slope*$y + $x; 
	    if($cur_x < 0 || $cur_x >= $x_max) { $skipped_line = 1; last; } #if the line goes off the left or right side of image, skip that line
	    else
	    {
		$cur_x = int($cur_x + .5); #round x-value
		if($cur_x < 0 || $cur_x >= $x_max) { $skipped_line = 1; last; } #(take care of rounding up to 624)
		else { $intensity_sum += $gel[$cur_x][$y]; }
		
	    }
            if(!$first_sum && $intensity_sum > $min_intensity_sum[$x]) { last; }
        }
        if(!$skipped_line && ($first_sum || $intensity_sum < $min_intensity_sum[$x]))
        {
            $min_intensity_sum[$x] = $intensity_sum;
            $min_intensity_sum_i[$x] = $i;
            $first_sum = 0;
        }
    }
}

# (2) for each lane, find the x corresponding to the minimum i-line for start and end of lane
my @lane_x; my $lane_i = 0;
my $prev_end_lane_x = 0;
while($lane_i < $num_lanes && $prev_end_lane_x < $x_max) 
{#find start of lane:
    
	#use end of previous lane as the start of this lane
	my $cur_start_lane_x = $prev_end_lane_x;
	$lane_x[$lane_i][0] = $cur_start_lane_x;
	$lane_x[$lane_i][1] = $lane_i > 0 ? $lane_x[$lane_i-1][3] : $min_intensity_sum_i[$cur_start_lane_x];
	
	#allow extra room for first lane
	my $cur_max_lane_width = $max_lane_width;
	if($lane_i == 0) { $cur_max_lane_width += 5; }

	#find end of lane:
	my $cur_end_lane_x = $cur_start_lane_x + $min_lane_width;
	if($cur_end_lane_x >= $x_max) { $cur_end_lane_x = $x_max-1; }
	for(my $x = $cur_end_lane_x+1; $x < $cur_start_lane_x+$cur_max_lane_width; $x++)
	{
	    if($x >= $x_max) { last; } #running off the end of the image, stop
	     
	    if($min_intensity_sum[$x] < $min_intensity_sum[$cur_end_lane_x])
	    {
		    $cur_end_lane_x = $x;
	    }
	}

	my $x2_lane_diff = abs(($cur_end_lane_x + $min_intensity_sum_i[$cur_end_lane_x]) - ($lane_x[$lane_i][0] + $lane_x[$lane_i][1]));
	if($x2_lane_diff < $min_lane_width)
	{#something is wrong, lane width is < min or > max: correct this by increasing/reducing i and x
		
		#increase i and x so that lane width == min
		my $add_to_diff = $min_lane_width - $x2_lane_diff;
		
		#checking for image runoff that could happen in last lane when increasing i
		if($x_max - ($cur_end_lane_x+$min_intensity_sum_i[$cur_end_lane_x]) <= $add_to_diff)
		{ $add_to_diff = $x_max - ($cur_end_lane_x+$min_intensity_sum_i[$cur_end_lane_x])-1; }
		
		#moving the end line over/changing the slant a little to get it within range
		my $add_to_i; my $add_to_x;
		if($add_to_diff <= 3) { $add_to_i = $add_to_diff; $add_to_x = 0; }
		else
		{
			if($add_to_diff % 4 == 0) { $add_to_i = $add_to_diff * 3/4; $add_to_x = $add_to_diff * 1/4; }
			else { $add_to_i = int($add_to_diff * 3/4) + 1; $add_to_x = int($add_to_diff * 1/4); }
		}
		
		$lane_x[$lane_i][2] = $cur_end_lane_x + $add_to_x;
		$lane_x[$lane_i][3] = $min_intensity_sum_i[$cur_end_lane_x] + $add_to_i;
		
		my $lane_i_display = $lane_i+1;
		print LOG "Increasing x for lane $lane_i_display (adding $add_to_x to $cur_end_lane_x).\n";
		print LOG "Increasing i for lane $lane_i_display (adding $add_to_i to $min_intensity_sum_i[$cur_end_lane_x]).\n";
	} 
	elsif($x2_lane_diff > $cur_max_lane_width)
	{
		#decrease i and x so that lane width == max
		my $sub_from_diff = $x2_lane_diff - $cur_max_lane_width;
		
		#moving the end line over/changing the slant a little to get it within range
		my $sub_from_i; my $sub_from_x;
		if($sub_from_diff <= 3) { $sub_from_i = $sub_from_diff; $sub_from_x = 0; }
		else
		{
			if($sub_from_diff % 4 == 0) { $sub_from_i = $sub_from_diff * 3/4; $sub_from_x = $sub_from_diff * 1/4; }
			else { $sub_from_i = int($sub_from_diff * 3/4) + 1; $sub_from_x = int($sub_from_diff * 1/4); }
		}
		
		$lane_x[$lane_i][2] = $cur_end_lane_x - $sub_from_x;
		$lane_x[$lane_i][3] = $min_intensity_sum_i[$cur_end_lane_x] - $sub_from_i;
		
		my $lane_i_display = $lane_i+1;
		print LOG "Decreasing x for lane $lane_i_display (subtracting $sub_from_x from $cur_end_lane_x).\n";
		print LOG "Decreasing i for lane $lane_i_display (subtracting $sub_from_i from $min_intensity_sum_i[$cur_end_lane_x]).\n";
		
	}
	else
	{
		$lane_x[$lane_i][2] = $cur_end_lane_x;
		$lane_x[$lane_i][3] = $min_intensity_sum_i[$cur_end_lane_x];
	}
	    
	$prev_end_lane_x = $lane_x[$lane_i][2];
	$lane_i++;
}

my $num_found_lanes = $lane_i;
if($num_found_lanes != $num_lanes) { print LOG "Error: Did not find $num_lanes lanes ($num_found_lanes lanes found).\n"; }
# (3) now we have the x and i values, draw the line from (x, 0) to (x + i, y_max)
for($lane_i = 0; $lane_i < $num_found_lanes; $lane_i++)
{
	my $lane_i_display = $lane_i+1;
	
	my $cur_st_lane_x1 = $lane_x[$lane_i][0];
	my $cur_st_lane_x2 = $cur_st_lane_x1 + $lane_x[$lane_i][1];
	
	my $cur_end_lane_x1 = $lane_x[$lane_i][2];
	my $cur_end_lane_x2 = $cur_end_lane_x1 + $lane_x[$lane_i][3];
	
	print LOG "Lane $lane_i_display start: $cur_st_lane_x1,0 $cur_st_lane_x2,$y_max (x = $cur_st_lane_x1, i = $lane_x[$lane_i][1])\n";
	print LOG "Lane $lane_i_display end  : $cur_end_lane_x1,0 $cur_end_lane_x2,$y_max (x = $cur_end_lane_x1, i = $lane_x[$lane_i][3])\n";
	
	if(!open(IN, $gel_txt_file)) { print LOG "Could not input text file ($gel_txt_file).\n"; last; }
	if(!open(IN_N, $n_gel_txt_file)) { print LOG "Could not input text file ($n_gel_txt_file).\n"; last; }
	if(!open(IN_NN, $nn_gel_txt_file)) { print LOG "Could not input text file ($nn_gel_txt_file).\n"; last; }
	if(!open (OUT, ">$gel_image_file_root.lane.$lane_i_display.txt")) { print LOG "Could not create $gel_image_file_root.lane.$lane_i_display.txt\n"; last; }
	if(!open (OUT_N, ">$gel_image_file_root.lane.$lane_i_display.n.txt")) { print LOG "Could not create $gel_image_file_root.lane.$lane_i_display.n.txt\n"; last; }
	if(!open (OUT_NN, ">$gel_image_file_root.lane.$lane_i_display.nn.txt")) { print LOG "Could not create $gel_image_file_root.lane.$lane_i_display.nn.txt\n"; last; }
	
	my $start_x = $lane_x[$lane_i][1] >= 0 ? $cur_st_lane_x1 : $cur_st_lane_x2;
	my $end_x = $lane_x[$lane_i][3] <= 0 ? $cur_end_lane_x1 : $cur_end_lane_x2;
	my $line_n; my $line_nn; my $type=''; my $max_intensity='';
	while ($line=<IN>)
	{
		if($line_n=<IN_N>)
		{
			if ($line_nn=<IN_NN>)
			{
				if($line=~/^# ImageMagick pixel enumeration\: ([0-9]+),([0-9]+),([0-9]+),(s?rgb|graya?)/)
				{
					# we will only output the current lane that we are processing to the text file
					my $window_size = ($end_x - $start_x) + 1;
					$max_intensity = $3;
					$type = $4;
					print OUT qq!# ImageMagick pixel enumeration: $window_size,$2,$max_intensity,$type\n!;
					
					$line_n=~/^# ImageMagick pixel enumeration\: ([0-9]+),([0-9]+),([0-9]+),(s?rgb|graya?)/;
					print OUT_N qq!# ImageMagick pixel enumeration: $window_size,$2,$3,$4\n!;
					$line_nn=~/^# ImageMagick pixel enumeration\: ([0-9]+),([0-9]+),([0-9]+),(s?rgb|graya?)/;
					print OUT_NN qq!# ImageMagick pixel enumeration: $window_size,$2,$3,$4\n!;
				}
				elsif($line=~/^([0-9]+),([0-9]+):\s\(\s*([0-9]+),\s*([0-9]+),\s*([0-9]+)[,\)]/)
				{
					my $x=$1;
					my $y=$2;
					
					if($x >= $start_x && $x <= $end_x) 
					{
						my $x_ = $x - $start_x;
						
						if ($x<=$cur_st_lane_x1+$y/$y_max*($cur_st_lane_x2-$cur_st_lane_x1)) #we are in the cutout triangle (left side)
						#{ print OUT qq!$x_,$y:(65535,    0,    0)  #FFFF00000000  red\n!; }
						{
							if($max_intensity eq '65535') 
							{
								print OUT qq!$x_,$y: (65535,65535,65535)  #FFFFFFFFFFFF  white\n!;
							}
							else
							{# $max_intensity eq '255'
								if ($type eq 'graya')
								{
									print OUT qq!$x_,$y: (255,255,255,255)  #FFFFFF  graya(255,255,255,1)\n!;
								}
								else
								{
									print OUT qq!$x_,$y: (255,255,255)  #FFFFFF  gray(255,255,255)\n!;
								}
								
							}
						}
						#{ ; }
						else
						{
							if ($x>=$cur_end_lane_x1+$y/$y_max*($cur_end_lane_x2-$cur_end_lane_x1)) #we are in the cutout triangle (right side)
							#{ print OUT qq!$x_,$y:(65535,    0,    0)  #FFFF00000000  red\n!; }
							{
								if($max_intensity eq '65535') 
								{
									print OUT qq!$x_,$y: (65535,65535,65535)  #FFFFFFFFFFFF  white\n!;
								}
								else
								{# $max_intensity eq '255'
									if ($type eq 'graya')
									{
										print OUT qq!$x_,$y: (255,255,255,255)  #FFFFFF  graya(255,255,255,1)\n!;
									}
									else
									{
										print OUT qq!$x_,$y: (255,255,255)  #FFFFFF  gray(255,255,255)\n!;
									}
									
								}
							}
							
							#{ ; }
							else 
							{ 
								#print out the slanted lane
								$line =~ s/^([0-9]+)/$x_/; print OUT qq!$line!;
								$line_n =~ s/^([0-9]+)/$x_/; print OUT_N qq!$line_n!;
								$line_nn =~ s/^([0-9]+)/$x_/; print OUT_NN qq!$line_nn!;
							} 
						}
					}
				}
				else { print LOG "Alert!  Error reading line of image file: '$line'\n"; }
			} else { print LOG "Alert! Error reading line of norm'd (2) image file (line of image file: '$line').\n"; }
		} else { print LOG "Alert! Error reading line of norm'd image file (line of image file: '$line').\n"; }
	}
	close(IN);
	close(OUT);
	close(IN_N);
	close(OUT_N);
	close(IN_NN);
	close(OUT_NN);
	
	my $ROTATE = 1;
	if ($ROTATE)
	{
		#rotate the lane:
		my $i = int(($lane_x[$lane_i][1] + $lane_x[$lane_i][3]) / 2); #average the st/end i's to get i-value for rotation
		my $rotate_angle = $im_rot_angles{$i};
		
		if($i != 0) 
		{
			#rotate
			my $ret = `"$IMAGEMAGICK_DIR/mogrify" "-rotate" "$rotate_angle" "$gel_image_file_root.lane.$lane_i_display.txt" 2>&1`;
			print LOG "Performed ImageMagick rotate ($ret) for Lane $lane_i_display, angle = $rotate_angle.\n";
			
			$ret = `"$IMAGEMAGICK_DIR/mogrify" "-rotate" "$rotate_angle" "$gel_image_file_root.lane.$lane_i_display.n.txt" 2>&1`;
			print LOG "Performed ImageMagick rotate ($ret) for (norm) Lane $lane_i_display, angle = $rotate_angle.\n";
			
			$ret = `"$IMAGEMAGICK_DIR/mogrify" "-rotate" "$rotate_angle" "$gel_image_file_root.lane.$lane_i_display.nn.txt" 2>&1`;
			print LOG "Performed ImageMagick rotate ($ret) for (norm2) Lane $lane_i_display, angle = $rotate_angle.\n";
			
			#trim/shave extra whitespace
			$ret = `"$IMAGEMAGICK_DIR/mogrify" "-fuzz" "1%" "-trim" "$gel_image_file_root.lane.$lane_i_display.txt" 2>&1`;
			print LOG "Performed ImageMagick trim ($ret) for Lane $lane_i_display.\n";
			
			$ret = `"$IMAGEMAGICK_DIR/mogrify" "-fuzz" "1%" "-trim" "$gel_image_file_root.lane.$lane_i_display.n.txt" 2>&1`;
			print LOG "Performed ImageMagick trim ($ret) for (norm) Lane $lane_i_display.\n";
			
			$ret = `"$IMAGEMAGICK_DIR/mogrify" "-fuzz" "1%" "-trim" "$gel_image_file_root.lane.$lane_i_display.nn.txt" 2>&1`;
			print LOG "Performed ImageMagick trim ($ret) for (norm2) Lane $lane_i_display.\n";
		}
	}
	
	
	
	#convert to png file
	my $ret = `"$IMAGEMAGICK_DIR/mogrify" "-format" "png" "$gel_image_file_root.lane.$lane_i_display.txt" 2>&1`;
	print LOG "Performed ImageMagick format ($ret) for Lane $lane_i_display.\n";
	
	$ret = `"$IMAGEMAGICK_DIR/mogrify" "-format" "png" "$gel_image_file_root.lane.$lane_i_display.n.txt" 2>&1`;
	print LOG "Performed ImageMagick format ($ret) for (norm) Lane $lane_i_display.\n";
	
	$ret = `"$IMAGEMAGICK_DIR/mogrify" "-format" "png" "$gel_image_file_root.lane.$lane_i_display.nn.txt" 2>&1`;
	print LOG "Performed ImageMagick format ($ret) for (norm2) Lane $lane_i_display.\n";
}

close(LOG);