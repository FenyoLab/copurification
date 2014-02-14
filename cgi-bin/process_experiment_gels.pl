#!c:/perl/bin/perl.exe 

#    process_experiment_gels.pl - this module is executed by copurification.pl,
#    it calls the scripts that section the gels/find the bands, masses/quantification
#
#    Copyright (C) 2014  Sarah Keegan
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

# Processes the gels in a given directory
# calls the following perl scripts/programs (for all gels in the given directory) - 
# 1) (ImageMagick) convert - to auto-level, scale and convert the image to txt file
# 2) find_lane_boundaries.pl - to calculate the lane start and ends 
# 3) find_lane_masses.pl - to calculate the lane masses for each lane (found by find_lane_boundaries.pl)
# 4)  - NOT IMPLEMENTED! - calculate_lane_scores.pl - calculates a match score for each lane and creates a lane match image for all lanes in all gels in the given directory

use lib "../lib";

#use warnings;
use strict;
use Biochemists_Dream::GelDB;
use Biochemists_Dream::Common;

my $experiment_id;
my $experiment_dir;
my $x_pixels_per_lane = 24;
my $y_size = 300;
my $shave_percent = .01;

#arguments on the command line are experiment_id (PK in the database), and experiment_dir (where to find the gel files, etc.)
if($#ARGV != 1) 
{ exit(0); }
else
{
	$experiment_id = $ARGV[0];
	$experiment_dir = $ARGV[1];
}

#open a log file, write error messages, and 'DONE' indicator when exiting, so that CGI program can check for progress or print error text to user
open(LOG, ">$experiment_dir/$PROCESS_GELS_LOG_FILE_NAME") || exit(0);

#open settings file and read data directory:
my $err = "";
if($err = read_settings()) 
{ 	
	print LOG "ERROR: Cannot load settings file: $err\n";
	exit(0);
}

eval
{
	#for each gel in the experiment directory, call find_lane_boundaries.pl
	#must connect to DB to get the number of lanes (e.g. 26)
	my $exp = Biochemists_Dream::Experiment -> retrieve($experiment_id);
	my @gels = $exp -> gels();
	my @file_names = <$experiment_dir/$GEL_DATA_FILE_NAME_ROOT*.*>; 
	my $cur_gel_img_file;
	my $cur_gel_txt_file;
	my $n_cur_gel_txt_file; my $nn_cur_gel_txt_file;
	my $cur_gel_img_file_root;
	
	foreach my $gel (@gels)
	{
		my $n = $gel -> get("File_Id");
		my $ext = $gel -> get("File_Type");
		my $lanes = $gel -> get("Num_Lanes");
		my $gel_id = $gel -> get("Id");
		$cur_gel_img_file = "";
		
		#go thru file list from glob and check that the current gel file exists
		foreach my $cur_file (@file_names)
		{
			my $fn = 'gel' . "$n.$ext";
			$cur_gel_img_file_root = 'gel' . "$n";
			if($cur_file =~ /$fn$/)
			{
				
				$cur_gel_img_file = $cur_file;
				
				$cur_file =~ s/\.\w\w\w$/.txt/;
				$cur_gel_txt_file = $cur_file;
				$cur_file =~ s/.txt$/-n.txt/;
				$n_cur_gel_txt_file = $cur_file;
				$cur_file =~ s/-n.txt$/-nn.txt/;
				$nn_cur_gel_txt_file = $cur_file;
						
				last;
			}
		}
		
		if($cur_gel_img_file eq "")
		{
			$gel -> set('Error_Description' => "Could not find gel file in Experiment directory.");
			$gel -> update();
			next;
		}
		
		

		
		#imagemagick convert - convert to grayscale and resize
		my $x_size = $lanes * $x_pixels_per_lane;
		my $sys_ret = system(qq!"$IMAGEMAGICK_DIR/convert" "$cur_gel_img_file" -colorspace Gray -scale ${x_size}x${y_size}\! "$cur_gel_txt_file"!);
		if($sys_ret != 0) #getting error here with png image - try running it manually....
		{
			$gel -> set('Error_Description' => "Error in processing gel image file. (convert (1) error)");
			$gel -> update();
			next;
		}
		
		##imagemagick convert - shave off top/bottom 1% of image, there are lines there that are not bands, possibly affecting the program
		#my $to_shave = $y_size * $shave_percent; 
		#$sys_ret = system(qq!"$IMAGEMAGICK_DIR/convert" "$cur_gel_txt_file" "-shave" "0x$to_shave\!" "$cur_gel_txt_file"!);
		#if($sys_ret != 0)
		#{
		#	$gel -> set('Error_Description' => "Error in processing gel image file. (convert (2) error)");
		#	$gel -> update();
		#	next;
		#}
		
		#imagemagick convert - normalize the image (used for display option)
		$sys_ret = system(qq!"$IMAGEMAGICK_DIR/convert" "$cur_gel_txt_file" -contrast-stretch 1\%x1\% "$n_cur_gel_txt_file"!);
		if($sys_ret != 0)
		{
			$gel -> set('Error_Description' => "Error in processing gel image file. (convert (3) error)");
			$gel -> update();
			next;
		}
		$sys_ret = system(qq!"$IMAGEMAGICK_DIR/convert" "$cur_gel_txt_file" -contrast-stretch 2\%x2\% "$nn_cur_gel_txt_file"!);
		if($sys_ret != 0)
		{
			$gel -> set('Error_Description' => "Error in processing gel image file. (convert (4) error)");
			$gel -> update();
			next;
		}
		
		#imagemagick convert - auto-level the image
		$sys_ret = system(qq!"$IMAGEMAGICK_DIR/convert" "$cur_gel_txt_file" -auto-level "$cur_gel_txt_file"!);
		if($sys_ret != 0)
		{
			$gel -> set('Error_Description' => "Error in processing gel image file. (convert (5) error)");
			$gel -> update();
			next;
		}
		
		#call find_lane_boundaries.pl
		$sys_ret = system(qq!"../finding_lane_boundaries/find_lane_boundaries2.pl" "$cur_gel_txt_file" "$lanes"!);
		
		#create mass cal file - read in mass cal lanes numbers and amount cal lane numbers and amount(s)
		open(OUT, ">$experiment_dir/calibration.txt");
		
		#mass cal lanes
		my @mass_cal_lanes = Biochemists_Dream::Lane -> search(Gel_Id => $gel_id, Mol_Mass_Cal_Lane => '1');
		print OUT $#mass_cal_lanes+1;
		print OUT "\n";
		if($#mass_cal_lanes >= 0)
		{#should not happen now since it is checked when reading in gel data file
			
			#print out number of mass cal lanes and the lane number of each
			
			foreach my $cl (@mass_cal_lanes) { print OUT $cl -> get("Lane_Order"); print OUT "\t"; }
			print OUT "\n";
			foreach my $cl (@mass_cal_lanes)
			{#print out mass ladder
				my $gel_ladder_id = $cl -> get('Ladder_Id');
				my @ladder_masses = Biochemists_Dream::Ladder_Mass -> search(Ladder_Id => $gel_ladder_id);
				my @the_masses;
				foreach my $lm (@ladder_masses)
				{
					push @the_masses, $lm -> get('Mass');
				}
				print OUT join(',', @the_masses);
				print OUT "\t";
			}
		}
		print OUT "\n";
		
		#print out number of amount cal lanes and the lane number of each and then amount of each
		my @amt_cal_lanes;
		if($ALLOWED_GEL_FILE_TYPES{lc $ext} eq 'Q') #ignore amount cal info if gel image type is not Quantifiable
		{
			@amt_cal_lanes = Biochemists_Dream::Lane -> search(Gel_Id => $gel_id, Quantity_Std_Cal_Lane => '1');
			print OUT $#amt_cal_lanes+1;
			print OUT "\n";
			if($#amt_cal_lanes >= 0)
			{
				foreach my $cl (@amt_cal_lanes) { print OUT $cl -> get("Lane_Order"); print OUT "\t"; }
				print OUT "\n";
				foreach my $cl (@amt_cal_lanes) { print OUT $cl -> get("Quantity_Std_Amount"); print OUT "\t"; }
				print OUT "\n";
				foreach my $cl (@amt_cal_lanes) { print OUT $cl -> get("Quantity_Std_Size"); print OUT "\t"; }
				print OUT "\n";
			}
		}
		else { print OUT "0\n"; }
		
		close(OUT);
		
		#call find_lane_masses
		system(qq!"../finding_lane_boundaries/find_lane_masses.pl" "$experiment_dir" "$cur_gel_img_file_root" "$lanes" "calibration.txt"!); #fix the input parameters in this program to match here...
	
		#gel all lanes for this gel (in order 1 to max), add bands that were found by the program:
		my @db_lane = Biochemists_Dream::Lane -> search(Gel_Id => $gel_id, { order_by => 'Lane_Order' });
		my $lane_i = 1; my $missing_lanes = 0;
		my $output_file = $LANE_OUTPUT_FILE_FORMAT;
		$output_file =~ s/#root#/$cur_gel_img_file_root/;
		foreach my $cur_db_lane (@db_lane)
		{
			my $cur_output_file = $output_file;
			$cur_output_file =~ s/#i#/$lane_i/;
			if(!open(IN, "$experiment_dir/$cur_output_file"))
			{
				$missing_lanes = 1;
				$cur_db_lane -> set('Error_Description' => "Lane $lane_i file not found ($cur_output_file) in Experiment dir ($experiment_dir) for gel $cur_gel_img_file_root." );
				$cur_db_lane -> update();
			}
			else
			{
				#read in mass data and save to DB
				my $lane_id = $cur_db_lane -> get("Id"); 
				
				#read in the masses and pixel start and end and create the bands
				my $line = <IN>;
				while($line = <IN>)
				{
					my $mass; my $start; my $end; my $amount = undef; my $mass_error = undef; my $amount_error = undef;
					chomp($line);
					if ($line =~ s/^([0-9\.]+)\s+([0-9]+)\s+([0-9]+)\s+([0-9]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)//)
					{#first 7 columns
						$mass = $1; $start = $3; $end = $4; 
					
						if($#mass_cal_lanes > 0)
						{#mass error at next column
							$line =~ s/^\s+([0-9\.]+)//;
							$mass_error = $1;
						}
					
						if($#amt_cal_lanes >= 0)
						{#amount at next column
							$line =~ s/^\s+([0-9\.]+)//;
							$amount = $1;
							
							if ($#amt_cal_lanes > 0)
							{#amount error at next column
								$line =~ s/^\s+([0-9\.]+)//;
								$amount_error = $1;
							}
						}
					}
					
					$mass = sprintf("%.2f", $mass);
					if($mass_error) { $mass_error = sprintf("%.2f", $mass_error); }
					if($amount) { $amount = sprintf("%.4f", $amount); }
					if($amount_error) { $amount_error = sprintf("%.4f", $amount_error); }
					
					#create bands for each mass listed in file
					my $band = Biochemists_Dream::Band -> insert({Lane_Id => $lane_id, Mass => $mass, Mass_Error => $mass_error, Start_Position => $start,
										      End_Position => $end, Quantity => $amount, Quantity_Error => $amount_error});	
				}
				
				#create blank image that is same size/shape as lane image
				#write the masses on top of the image at the band positions
				
				
			}
			$lane_i++;
			
		}
		if($missing_lanes)
		{
			$gel -> set('Error_Description' => "One or more lanes could not be found on gel image." );
			$gel -> update();
		}	
	}
};

if ($@) 
{
    print LOG "ERROR: \'$@\'\n";
}

print LOG "DONE\n";
close(LOG);

