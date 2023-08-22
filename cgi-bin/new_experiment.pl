#!/usr/bin/perl

#
#    Copyright (C) 2022  Sarah Keegan
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

#use warnings;
use strict;
use Biochemists_Dream::GelDB;
use Biochemists_Dream::Common;
use Biochemists_Dream::GelDataFileReader;
use Proc::Background;

# reads all data in and adds information to database as an experiment with gels

my $experiment_id;
my $experiment_dir_root;
my $exp_species;
my $gel_rem_fname_list;
my $gel_fname_list;
my $gel_fname_ext_list;
	
if($#ARGV != 5) 
{ exit(0); }
else
{
	$experiment_id = $ARGV[0];
	$experiment_dir_root = $ARGV[1];
	$exp_species = $ARGV[2];
	$gel_rem_fname_list = $ARGV[3];
	$gel_fname_list = $ARGV[4];
	$gel_fname_ext_list = $ARGV[5];
}



my $experiment_dir="$experiment_dir_root/$experiment_id";

#open a log file, write error messages, and 'DONE' indicator when exiting, so that CGI program can check for progress or print error text to user
open(LOG, ">$experiment_dir_root/new_experiment_log_$experiment_id.txt") || exit(0);
print LOG "<br>\n";

#print LOG "Input gel file params: '$gel_rem_fname_list' '$gel_fname_list' '$gel_fname_ext_list'\n<br>";

#open settings file and read data directory:
my $err = "";
if($err = read_settings()) 
{ 	
	print LOG "ERROR: Cannot load settings file: $err\n<br>";
	exit(0);
}

eval
{
	
	# Convert parameters to DICT objects
	my @spl_rem = split('/', $gel_rem_fname_list);
	my @spl_loc = split('/', $gel_fname_list);
	my @spl_ext = split('/', $gel_fname_ext_list);
	my %gel_fname_map;
	my %gel_fname_ext_map;
	my $i=0;
	foreach my $rem_fname (@spl_rem) 
	{
		$gel_fname_map{lc $rem_fname} = $spl_loc[$i];
		$gel_fname_ext_map{lc $rem_fname} = $spl_ext[$i];
		$i+=1;
	}
	
	print LOG "Loading the experiment data file...\n<br>";
	
	$Biochemists_Dream::GelDataFileReader::data_file_name = "$experiment_dir/$EXP_DATA_FILE_NAME_ROOT.txt";
	$Biochemists_Dream::GelDataFileReader::species = $exp_species;
	$Biochemists_Dream::GelDataFileReader::file_extension_map = \%gel_fname_ext_map;
	
	my $output_msg="";
	if(!Biochemists_Dream::GelDataFileReader::read_file())
	{
		$output_msg = format_error_message(\@Biochemists_Dream::GelDataFileReader::read_error_message);
		my $ret_val = delete_on_error($experiment_id, $experiment_dir);
		print LOG "ERROR: $output_msg\n<br>";
		if ($ret_val) { print LOG "ERROR: $ret_val\n<br>"; }
	}
	else
	{
		#success! reading in file - all is valid!
		print LOG "Finished loading the experiment data file...\n<br>";
		
		#navigate through gels, lanes...
		my %proteins_added;
		while(read_gel())
		{
			my $fname = get_gel_file_name();
			my $fname_orig = get_gel_file_name_orig(); #not made to lower case
			if(!defined $gel_fname_map{$fname})
			{
				#error this file name from the data file doesn't correspond to an uploaded image file...
				#this should not happen since its already checked in the GelDataFileReader package
				next;
			}

			my $new_gel = Biochemists_Dream::Gel -> insert({Experiment_Id => $experiment_id, File_Id => $gel_fname_map{$fname}, Num_Lanes => get_num_lanes(),
									Display_Name => $fname_orig, File_Type => $gel_fname_ext_map{$fname}});
			my $gel_id = $new_gel -> get("Id");
			
			while(read_lane())
			{
				#create new lane:
				my $new_lane =  Biochemists_Dream::Lane -> insert({Gel_Id => $gel_id, Lane_Order => get_lane_index()});
				
				#next, check if its calibration lane:
				
				my $ladder_ref = get_mass_ladder();
				if(@{$ladder_ref})
				{#create ladder in db
					my $new_ladder = Biochemists_Dream::Ladder -> insert({Name => 'ladder'});
					my $ladder_id = $new_ladder -> get("Id");
					foreach (@{$ladder_ref})
					{
						Biochemists_Dream::Ladder_Mass -> insert({Ladder_Id => $ladder_id, Mass => $_});
					}
					
					#add ladder to Lane
					$new_lane -> set(Mol_Mass_Cal_Lane => 1, Ladder_Id => $ladder_id);
					$new_lane -> update();
				}
				
				my $qty_std_data_ref = get_qty_std_data();
				
				if(@{$qty_std_data_ref})
				{#add qty std calibration info. to lane
					$new_lane -> set(Quantity_Std_Cal_Lane => 1, Quantity_Std_Name => ${$qty_std_data_ref}[0], Quantity_Std_Amount => ${$qty_std_data_ref}[1], Quantity_Std_Units => ${$qty_std_data_ref}[2], Quantity_Std_Size => ${$qty_std_data_ref}[3]);
					$new_lane -> update();
				}
				
				if(@{$ladder_ref} || @{$qty_std_data_ref}) { next; } #if its a cal. lane, the rest of the lane details are not used.
				
				#not a cal lane, retreive rest of lane details and insert lane
				
				#get protein info: either protein id (if already in db) or protein name (if need to add it)
				my $p_id; 
				if(!($p_id = get_protein_id_in_db()))
				{#must add protein -  but check if it was already added by this statement for an earlier lane and if so don't add it...
					my $sys_name = get_protein_sys_name();
					if(!defined $proteins_added{$sys_name})
					{
						my $new_protein = Biochemists_Dream::Protein_DB_Entry -> insert({Protein_DB_Id => get_protein_db_id_in_db(), Systematic_Name => $sys_name,
													 Common_Name => get_protein_common_name()});
						$proteins_added{$sys_name} = $new_protein -> get("Id");
					}
					$p_id = $proteins_added{$sys_name};
				}
				
				#Protein ID + Ph, Over_Expressed, Tag_Type, Tag_Location, Antibody, Other_Capture, Notes, Single Reagent Flag
				$new_lane -> set(Captured_Protein_Id => $p_id, Ph => get_ph(), Tag_Location => get_tag_location(), Over_Expressed => get_over_expressed(),
						 Tag_Type => get_tag_type(), Antibody => get_antibody(), Other_capture => get_other_capture(), Notes => get_notes(), Single_Reagent_Flag => get_single_reagent_flag(),
						 Elution_Method => get_elution_method(), Elution_Reagent => get_elution_reagent());
				$new_lane -> update();
				my $lane_id = $new_lane -> get('Id');
				
				#add the Reagents
				my $cur_reagents_array_ref;
				
				$cur_reagents_array_ref = get_detergents();
				foreach my $reag (@{$cur_reagents_array_ref})
				{
					Biochemists_Dream::Lane_Reagents -> insert({Lane_Id => $lane_id, Reagent_Id => ${$reag}[0], Amount => ${$reag}[1], Amount_Units => ${$reag}[2]});
					
				}
				
				$cur_reagents_array_ref = get_salts();
				foreach my $reag (@{$cur_reagents_array_ref})
				{
					Biochemists_Dream::Lane_Reagents -> insert({Lane_Id => $lane_id, Reagent_Id => ${$reag}[0], Amount => ${$reag}[1], Amount_Units => ${$reag}[2]});
				}
				
				$cur_reagents_array_ref = get_buffers();
				foreach my $reag (@{$cur_reagents_array_ref})
				{
					Biochemists_Dream::Lane_Reagents -> insert({Lane_Id => $lane_id, Reagent_Id => ${$reag}[0], Amount => ${$reag}[1], Amount_Units => ${$reag}[2]});
				}
				
				$cur_reagents_array_ref = get_other_reagents();
				foreach my $reag (@{$cur_reagents_array_ref})
				{
					Biochemists_Dream::Lane_Reagents -> insert({Lane_Id => $lane_id, Reagent_Id => ${$reag}[0], Amount => ${$reag}[1], Amount_Units => ${$reag}[2]});
				}
			}
		}
		
		print LOG "Success!  The experiment was created.  Please load the Experiment from the left window to check the progress of gel file processing.\n<br>";
		
		# process the gels files - split lanes, locate bands, etc etc
		my $proc1 = Proc::Background->new("perl", "process_experiment_gels.pl", "$experiment_id", "$experiment_dir");
	}
};

if ($@) 
{
    print LOG "ERROR: \'$@\'\n<br>";
}

close(LOG);

sub delete_on_error()
{
	my $exp_id = shift;
	my $experiment_dir = shift;
	
	my $err_str="";
	
	my $new_experiment = Biochemists_Dream::Experiment -> retrieve($exp_id);
	if($new_experiment) { $new_experiment -> delete(); }
	else { $err_str .= "No Experiment with id=$exp_id"; }
						
	my $ret_err = delete_directory($experiment_dir); 
	if($ret_err) { $err_str .= "$ret_err"; }
	
	return $err_str;
}

sub format_error_message
{
	my $array_ref = shift;
	my $ret_str = "";
	
	foreach (@{$array_ref})
	{
		$ret_str .= $_;
		$ret_str .= "<br>";
	}
	return $ret_str;
}

sub delete_directory
{
	my $dir = shift;
	my $err_str = "";
	if(opendir (DIR, $dir))
	{
		while (my $file = readdir(DIR))
		{
			if($file ne "." && $file ne "..")
			{ if(!unlink("$dir/$file")) {  $err_str = "Could not delete file ($dir/$file) - $!<br>"; last; } }
		}
		closedir(DIR);
	}
	else { $err_str = "Could not open directory ($dir) - $!<br>"; }

	if($err_str) { return $err_str; }

	if(!rmdir($dir)) { $err_str = "Could not remove directory ($dir) - $!<br>"; }

	return $err_str;
}
