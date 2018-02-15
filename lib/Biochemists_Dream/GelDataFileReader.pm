#!c:/perl/bin/perl.exe 

#    (Biochemists_Dream::GelDataFileReader) GelDataFileReader.pm - reads the tab-delimited 'Sample Descriptions' file
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

use lib "../";

use strict;
use warnings;

package Biochemists_Dream::GelDataFileReader;
#reads in a gel data file, validates the data and sets error messages
#if data is valid, the data can be read using the 'get' subroutines
#navigate to the first/next gel/lane using the read/reset_gel/lane subroutines

use Biochemists_Dream::Common;
use Biochemists_Dream::GelDB;
use Biochemists_Dream::ProteinNameValidator;

BEGIN {

require Exporter;

# set the version for version checking
our $VERSION = 1.00;

# Inherit from Exporter to export functions and variables
our @ISA = qw(Exporter);

# Functions and variables which are exported by default
our @EXPORT = qw(read_file read_gel reset_gels read_lane reset_lanes get_gel_file_name gel_gel_file_name_orig get_num_lanes get_lane_index
		get_mass_ladder get_qty_std_data get_ph get_protein_sys_name get_protein_common_name get_protein_id_in_db
		get_protein_db_id_in_db get_over_expressed get_tag_location get_tag_type get_antibody get_other_capture
		get_notes get_single_reagent_flag get_salts get_buffers get_detergents get_other_reagents $data_file_name $num_gels @read_error_message);

# Functions and variables which can be optionally exported
# added for mas spect udpate 05/05/2016
our @EXPORT_OK = qw(validate_protein_name);

}

# exported package globals go here

################################################################################################################################
####variables to set before calling read_file and iterating throught the data read in from the file (or getting error messages)

our $data_file_name; #the name of the data file to be read, must be set before calling read_file subroutine

our $species; #set species in order to verify protein systematic name in the database/online db's

our $file_extension_map; #address of hash that maps file name of gel image file (root only, no ext) to extension

################################################################################################################################

#if the read failed (sub 'Read_File' returns 0), then @read_error_message array contains the error messages
our @read_error_message;

#the number of gels in the data file
our $num_gels;

#the user will call read_next_gel/read_next_lane to iterate through all gels in the data file
#and use the get functions to read the data for the current gel/lane

# non-exported package globals go here
# (they are still accessible as $Some::Module::stuff)

our %allowed_column_names = ("gel file name" => "1", "lane # on gel" => "1", "total # of lanes on gel" => "1", "ph" => "1",
			     "mass ladder" => "1", "quantity std" => 1,
			     "protein systematic name" => "1", "tag location" => "1", "over-expressed" => "1", 
			     "tag type" => "1", "antibody" => "1",  "other capture" => "1", "notes" => "1", "single reagent flag" => "1",
			     "salt" => "1", "salt concentration" => "1", "salt unit" => "1",
			     "detergent" => "1", "detergent concentration" => "1", "detergent unit" => "1",
			     "buffer" => "1", "buffer concentration" => "1", "buffer unit" => "1",
			     "other" => "1", "other concentration" => "1", "other unit" => "1");

#the index of the current gel, starts at 0
our $current_gel_index;

#the index of the current lane, in the current gel, starts at 0
our $current_lane_index;

our @gel_file_names;
our %gel_file_names_orig; 
our @num_lanes;

our @mass_ladders;
our @qty_std_data;

our %reagents;

our @ph;
our @protein_name;
our @protein_common_name;
our @protein_id_in_db; #the Id (PK) in the Protein_DB_Entry table, if the protein already exists int he DB, else 0
our @protein_db_id_in_db; #The ID (PK) in the Protein_DB table, if the protein didn't exist in the DB, but was found online, indicates which DB it was found in, else 0
our @tag_location;
our @over_expressed;
our @tag_type; 
our @antibody; 
our @other_capture; 
our @notes;
our @single_reagent_flag;

my @valid_lane_numbers;

my %ORDERED_COLUMNS = ("salt" => 1, "buffer" => 1, "detergent" => 1, "other" => 1);
my %SINGLE_COLUMNS = ("gel file name" => 1, "lane # on gel" => 1, "total # of lanes on gel" => 1, "ph" => 1, "mass ladder" => "1", "quantity std" => "1", 
		      "protein systematic name" => 1, "tag location" => 1, "over-expressed" => 1, "tag type" => 1,
		      "antibody" => 1, "other capture" => 1, "notes" => 1, "single reagent flag" => 1);
my @MANDATORY_COLUMNS_IN_HEADER = ("gel file name", "lane # on gel", "total # of lanes on gel", "mass ladder", "quantity std", "over-expressed", "protein systematic name", "single reagent flag");
my %VALIDATION_COLS_TABLES = ('tag location' => 'Tag_Locations');
my %MANDATORY_COLUMNS_IN_DATA = ("gel file name" => 1, "lane # on gel" => 1, "over-expressed" => 1, "protein systematic name" => 1, "single reagent flag" => 1);

my %validation_tables;
my %valid_reagents;
my $dbh;

# functions

sub read_file
{#reads in the gel data file, returns -1 if there is a file read error or database connection error
#returns 0 if there is a data error (users data is invalid)
#@read_error_message contains the error messages
#returns 1 if no error
	
	my %read_error_message; #use this hash to avoid repeat error msgs, keys will be placed in @read_error_message array at the end
		
	eval
	{
		my %column_positions;
		
		#open the gel file
		if(!open(GELIN, $data_file_name))
		{ die "Could not open file $data_file_name."; }
		
		#remove any blank lines before header
		my $header = "";
		while($header eq "")
		{
			if($header = <GELIN>)
			{
				chomp($header);
				$header =~ s/^\s+//;
				$header =~ s/\s+$//;
			}
		}
		
		#read in header
		my $next_col_name = "";
		my %columns_found;
		my $fixed_col_name;
		#$header .= '\t'; 
		for(my $i = 0; $header && ($header =~ s/^([^\t]*)\t// || $header =~ s/^(.*)$//); $i++) #get (and remove) next part of line and tab
		{
			my $col_name = $1;
			
			if(!$col_name) { next; } #empty column, skip
			
			#remove quotes, extra spaces, make lowercase
			$col_name =~ s/^\s*\"?\s*//;
			$col_name =~ s/\s*\"?\s*$//;
			$col_name =~ s/\s+/ /;
			$col_name = lc($col_name);

			$fixed_col_name = "";
			
			if($next_col_name)
			{
				if($col_name eq $next_col_name)
				{
					$fixed_col_name = $col_name;
					$next_col_name = $col_name =~ s/ concentration// ? "$col_name unit" : "";
				}
				else
				{
					add_reagent_header_error_msg($next_col_name, \%read_error_message);
					$fixed_col_name = "";
					$next_col_name = "";
				}
			}
			elsif($SINGLE_COLUMNS{$col_name})
			{
				$fixed_col_name = $col_name;
			}
			elsif($ORDERED_COLUMNS{$col_name})
			{
				$fixed_col_name = $col_name;
				$next_col_name = "$col_name concentration";
			}
			else
			{
				foreach(keys %ORDERED_COLUMNS)
				{
					if($col_name eq "$_ concentration" || $col_name eq "$_ unit")
					{
						add_reagent_header_error_msg($col_name, \%read_error_message);
						$fixed_col_name = "";
						$next_col_name = "";
					}
				}
			}
				
			if($fixed_col_name)
			{
				if(defined $SINGLE_COLUMNS{$fixed_col_name})
				{
					if(!defined $columns_found{$fixed_col_name})
					{
						$column_positions{$i} = $fixed_col_name;
						$columns_found{$fixed_col_name} = $i;
					}
				}
				else
				{
					$column_positions{$i} = $fixed_col_name;
					push @{$columns_found{$fixed_col_name}}, $i;
				}
				
			}
		}
		
		if($next_col_name)
		{#error - we have a column name at the end that's missing its partner
			add_reagent_header_error_msg($next_col_name, \%read_error_message);
		}
		
		#(NOTE: if a column is repeated, (for those that shouldn't be) the program will use the first one found (reading from left to right))
		
		#validate all MANDATORY	column headers were found:
		foreach (@MANDATORY_COLUMNS_IN_HEADER)
		{
			if(!defined $columns_found{$_})
			{#add error message for the column that's not found
				push @read_error_message, "$_ was not found in the header.  It is a mandatory column.  Please see the template for help.";
			}
		}
		
		#return if there is any errors in header, it doesn't make sense to attempt to read in the data if there's errors in the header...
		if(@read_error_message) { die ""; } #break through eval to return
		
		#connect to database:
		my ($data_source, $db_name, $user, $password) = getConfig();
		
		$dbh = DBI->connect($data_source, $user, $password,  { RaiseError => 1, AutoCommit => 1 });
		if(!$dbh) { die "Could not connect to database for field validation."; }
		
		#load validation info. for columns from the database
		load_validation_tables_from_db();
	
		#read in data for gels/lanes and fill the variables
		my $line = "";
		my @cur_values;
		my $gel_num = 0;
		my %gel_file_names;
		my @lanes_count; #stores number of lanes encountered for a gel
		my @lanes_found; #stores the lane numbers of the lanes encountered for a gel, a hash for each gel
		my $line_i;
		my $prev_qty_std_units = ""; #only 1 type of units allowed for qty std
		for($line_i = 2; $line=<GELIN>; $line_i++)
		{
			#input the current line, remove any blank lines
			chomp($line); $line =~ s/^\s+//; $line =~ s/\s+$//; 
			while(!$line && ($line = <GELIN>))
			{ chomp($line); $line =~ s/^\s+//; $line =~ s/\s+$//; }
			if(!$line) { last; }
			
			@cur_values = ();
			for(my $i = 0; $line =~ /\w/; $i++)
			{
				if ($line =~ s/^([^\t]*)//)
				{
					my $value=$1;
					
					#remove quotes, extra spaces
					$value =~ s/^\s*\"?\s*//;
					$value =~ s/\s*\"?\s*$//;
					$value =~ s/\s+/ /;
					
					push @cur_values, $value;
				}
				$line =~ s/^\t//; #get rid of tab
			}
			
			#store the values in this line:
			my $cur_value;
			
			#Gel file name
			$cur_value = $cur_values[$columns_found{"gel file name"}];
			my $cur_gel_num;
			if($cur_value)
			{
				my $ext = "";
				my $cur_value_orig = $cur_value; #preserve case
				$cur_value = lc $cur_value;
				if($cur_value =~ s/\.(\w\w\w)$//)
				{ $ext = $1; }
				if(defined ${$file_extension_map}{$cur_value} && (!$ext || $ext eq ${$file_extension_map}{$cur_value}))
				{#if file name matches gel file and, if there was an extension, if it matches extension of gel file
					
					if(!defined $gel_file_names{$cur_value})
					{
						$gel_file_names{$cur_value} = $gel_num;
						$gel_file_names[$gel_num] = $cur_value;
						$gel_file_names_orig{$cur_value} = $cur_value_orig; #maps to file name as input by user, not lower case
						
						#initialize
						$num_lanes[$gel_num] = 0;
						
						$gel_num++;
					}
					$cur_gel_num = $gel_file_names{$cur_value}; #$cur_gel_fn contains index we're using for current gel
					
				}
				else
				{
					push @read_error_message, "Line $line_i: Gel file name does not match a gel image file name.";
					next;
				}
				
			}
			else
			{#error, 'Gel file name' is mandatory
				push @read_error_message, "Line $line_i: Missing a value for Gel file name.  This is a mandatory field.";
				next;
			}
			
			#Total # of lanes on gel
			$cur_value = $cur_values[$columns_found{"total # of lanes on gel"}];
			if($cur_value =~ /^[0-9\s]+$/) { $num_lanes[$cur_gel_num] = $cur_value; }
			
			#Lane # on gel
			my $cur_lane_num;
			$cur_value = $cur_values[$columns_found{"lane # on gel"}];
			if($cur_value =~ /^[0-9\s]+$/) #make sure its a digit since we'll use it in the arrays
			{
				if(defined $lanes_found[$cur_gel_num]{$cur_value})
				{#a line for this lane was already encountered - error!
					push @read_error_message, "Line $line_i: Repeated Lane # on gel: $cur_value, for gel $gel_file_names[$cur_gel_num].";
					next;
				}
				else
				{
					$cur_lane_num = $cur_value;
					$lanes_found[$cur_gel_num]{$cur_value} = 1; #mark this lane as found for current gel
					$lanes_count[$cur_gel_num]++; #count this lane to keep track of how many lanes found for current gel
					
					#initialize
					$mass_ladders[$cur_gel_num][$cur_lane_num] = ();
					$qty_std_data[$cur_gel_num][$cur_lane_num] = ();
					$ph[$cur_gel_num][$cur_lane_num] = undef;
					$protein_name[$cur_gel_num][$cur_lane_num] = undef;
					$protein_id_in_db[$cur_gel_num][$cur_lane_num] = 0;
					$protein_db_id_in_db[$cur_gel_num][$cur_lane_num] = 0;
					$tag_location[$cur_gel_num][$cur_lane_num] = undef;
					$over_expressed[$cur_gel_num][$cur_lane_num] = undef;
					$tag_type[$cur_gel_num][$cur_lane_num] = undef;
					$antibody[$cur_gel_num][$cur_lane_num] = undef;
					$other_capture[$cur_gel_num][$cur_lane_num] = undef;
					$notes[$cur_gel_num][$cur_lane_num] = undef;
					$single_reagent_flag[$cur_gel_num][$cur_lane_num] = undef;
					foreach my $cur_column (keys %ORDERED_COLUMNS)
					{ ${$reagents{$cur_column}}[$cur_gel_num][$cur_lane_num] = (); }
				}
			}
			else
			{#error, 'Lane # on gel' is mandatory
				push @read_error_message, "Line $line_i: Lane # on gel is missing or unrecognized.  This is a mandatory field.";
				next;
			}
			
			#mass ladder for this lane (if present)
			my $calibration_lane = 0;
			if(defined $columns_found{"mass ladder"})
			{
				$cur_value = $cur_values[$columns_found{"mass ladder"}];
				if($cur_value)
				{
					$calibration_lane = 1;
					
					#masses separated by comma, read in to array
					$cur_value =~ s/^\s*//;
					$cur_value =~ s/\s*$//;
					my @masses = split(',', $cur_value);
					my $err = 0;
					foreach (@masses)
					{
						$_ =~ s/^\s*//;
						$_ =~ s/\s*$//;
						if($_ =~ /^[0-9\.\s]+$/)
						{
							if($_ > 0) { push @{$mass_ladders[$cur_gel_num][$cur_lane_num]}, $_; }
						}
						else { $err = 1; last; }
					}
					if($err || $#{$mass_ladders[$cur_gel_num][$cur_lane_num]} == -1)
					{#if error or array is empty
						push @read_error_message, "Line $line_i: Mass ladder is not in the correct format.";
						$mass_ladders[$cur_gel_num][$cur_lane_num] = ();
						next; #not checking rest of line if error is in calibration lane
					}
				}
			}
			
			#qty std details for this lane (if present)
			my $quantifiable = $ALLOWED_GEL_FILE_TYPES{"${$file_extension_map}{$gel_file_names[$cur_gel_num]}"} eq 'Q';
			if(defined $columns_found{"quantity std"})
			{
				$cur_value = $cur_values[$columns_found{"quantity std"}];
				if($cur_value)
				{
					#if(!$quantifiable) #don't give error but it will not be used
					#{
					#	push @read_error_message, "Line $line_i: Quantity std not allowed for this type of gel file, ${$file_extension_map}{$gel_file_names[$cur_gel_num]} files cannot be quantified.";
					#	next;
					#}
					
					$calibration_lane = 1;
					
					#parse qty std data - it is separated by commas
					if($cur_value =~ /([^,]+),([^,]+),([^,]+),(.+)/)
					{
						my $name = $1;
						my $mass = $2;
						my $amount = $3;
						my $units = $4;
						$name =~ s/^\s+|\s+$//g;
						$mass =~ s/^\s+|\s+$//g;
						$amount =~ s/^\s+|\s+$//g;
						$units =~ s/^\s+|\s+$//g;
						
						#name
						$qty_std_data[$cur_gel_num][$cur_lane_num][0] = $name;
						#amount
						if($amount =~ /^[0-9\.\s]+$/ && $amount > 0)
						{
							$qty_std_data[$cur_gel_num][$cur_lane_num][1] = $amount;
							#units
							$units = lc($units);
							if($QUANTITY_STD_UNITS{$units})
							{
								if(!$prev_qty_std_units || $prev_qty_std_units eq $units)
								{
									$qty_std_data[$cur_gel_num][$cur_lane_num][2] = $units;
									$prev_qty_std_units = $units;
								}
								else
								{
									push @read_error_message, "Line $line_i: Quantity std units must be the same for all lanes in the gel.";
									next; #not checking rest of line if error is in calibration lane
								}
							}
							else
							{
								push @read_error_message, "Line $line_i: Quantity std units invalid.";
								next; #not checking rest of line if error is in calibration lane
							}
							#mass 
							if($mass =~ /^[0-9\.\s]+$/)
							{ $qty_std_data[$cur_gel_num][$cur_lane_num][3] = $mass; } 
							else
							{
								push @read_error_message, "Line $line_i: Quantity std mass is not in the correct format.";
								next; #not checking rest of line if error is in calibration lane
							}
						}
						else
						{
							push @read_error_message, "Line $line_i: Quantity std amount is not in the correct format.";
							next; #not checking rest of line if error is in calibration lane
						}
					}
					else
					{
						push @read_error_message, "Line $line_i: Quantity std is not in the correct format.";
						next; #not checking rest of line if error is in calibration lane
					}
				}
			}
			
			#protein systematic name - mandatory
			$cur_value = $cur_values[$columns_found{"protein systematic name"}];
			if($cur_value)
			{
				#format for comparison w/ proteins in DB
				$cur_value = uc $cur_value;
				$cur_value =~ s/^\s+//; $cur_value =~ s/\s+$//;
				
				my $ret; my $id_in_db; my $common_name;
				if(!($ret = validate_protein_name($cur_value, $id_in_db, $common_name)))
				{#name is not valid, can't be verified 
					push @read_error_message, "Line $line_i: The column Protein Systematic Name has an unrecognized value: $cur_value.";
				}
				elsif($ret > 0)
				{#name is valid, and its already in the DB
					$protein_id_in_db[$cur_gel_num][$cur_lane_num] = $id_in_db;
					$protein_name[$cur_gel_num][$cur_lane_num] = $cur_value; 
				}
				else
				{#name is valid, not already in the DB, but it was found in an online DB
					$protein_db_id_in_db[$cur_gel_num][$cur_lane_num] = $id_in_db;
					$protein_name[$cur_gel_num][$cur_lane_num] = $cur_value;
					$protein_common_name[$cur_gel_num][$cur_lane_num] = $common_name;
				}
			}
			elsif(!$calibration_lane) #error, mandatory field
			{ push @read_error_message, "Line $line_i: Missing a value for Protein systematic name.  This is a mandatory field."; }
	
			#the next columns must be validated from tables in the DB: - only one now....used to be more...
			foreach (keys %validation_tables)
			{
				if(defined $columns_found{$_})
				{
					$cur_value = $cur_values[$columns_found{$_}];
					if($cur_value)
					{
						#check this value is in the DB lookup table
						my %cur_lookup = %{$validation_tables{$_}};
						if($cur_lookup{lc $cur_value})
						{
							if($_ eq 'tag location') { $tag_location[$cur_gel_num][$cur_lane_num] = $cur_value; }
						}
						else { push @read_error_message, "Line $line_i: The column $_ has an unrecognized value: $cur_value - to suggest a new value be added for $_, please email the site administrator."; }
					}
					elsif($MANDATORY_COLUMNS_IN_DATA{$_} && !$calibration_lane) #error, mandatory field
					{ push @read_error_message, "Line $line_i: Missing a value for $_.  This is a mandatory field."; }
				}
			}
			
			#over-expressed - mandatory if(!$calibration_lane)
			$cur_value = $cur_values[$columns_found{"over-expressed"}];
			if($cur_value)
			{
				$cur_value = lc($cur_value);
				if($cur_value =~ /y|yes|n|no|u|unknown|i|indeterminate/)
				{
					if($cur_value =~ /y|yes/)
					{ $over_expressed[$cur_gel_num][$cur_lane_num] = 1; }
					elsif($cur_value =~ /n|no/)
					{ $over_expressed[$cur_gel_num][$cur_lane_num] = 0; }
					else
					{ $over_expressed[$cur_gel_num][$cur_lane_num] = undef; }
				}
				else
				{ push @read_error_message, "Line $line_i: Over-expressed is not in the correct format, acceptable values are: Yes, No, Unknown."; }
			}
			elsif(!$calibration_lane) #error, mandatory field
			{ push @read_error_message, "Line $line_i: Missing a value for Over-expressed.  This is a mandatory field."; }
			
			#single_reagent_flag - mandatory if(!$calibration_lane)
			$cur_value = $cur_values[$columns_found{"single reagent flag"}]; 
			if($cur_value)
			{
				$cur_value = lc($cur_value);
				if($cur_value =~ /y|yes|n|no/)
				{
					if($cur_value =~ /y|yes/)
					{ $single_reagent_flag[$cur_gel_num][$cur_lane_num] = 1; }
					else #if($cur_value =~ /n|no/)
					{ $single_reagent_flag[$cur_gel_num][$cur_lane_num] = 0; }
				}
				else
				{ push @read_error_message, "Line $line_i: Single reagent flag is not in the correct format, acceptable values are: Yes, No."; }
			}
			elsif(!$calibration_lane) #error, mandatory field
			{ push @read_error_message, "Line $line_i: Missing a value for Single reagent flag.  This is a mandatory field."; }
			
			#antibody - not mandatory
			my $no_antibody = 0;
			if(defined $columns_found{"antibody"})
			{
				$cur_value = $cur_values[$columns_found{"antibody"}];
				if($cur_value) { $antibody[$cur_gel_num][$cur_lane_num] = $cur_value; }
				else { $no_antibody = 1; }
			}
			else { $no_antibody = 1; }
			
			#other capture - not mandatory
			if(defined $columns_found{"other capture"})
			{
				$cur_value = $cur_values[$columns_found{"other capture"}];
				if($cur_value)
				{ $other_capture[$cur_gel_num][$cur_lane_num] = $cur_value; }
				#one of antibody or othere capture must be present
				elsif($no_antibody && !$calibration_lane) { push @read_error_message, "Line $line_i: Both Antibody and Other Capture cannot be blank for a lane."; }
			}
			#one of antibody or othere capture must be present
			elsif($no_antibody && !$calibration_lane) { push @read_error_message, "Line $line_i: Both Antibody and Other Capture cannot be blank for a lane."; }
			
			#tag type - not mandatory
			if(defined $columns_found{"tag type"})
			{
				$cur_value = $cur_values[$columns_found{"tag type"}];
				if($cur_value)
				{
					$tag_type[$cur_gel_num][$cur_lane_num] = $cur_value;
					#tag location (if tag type, then mandatory) - the value for this field has been verified above
					$cur_value = $cur_values[$columns_found{"tag location"}];
					if($cur_value) 
					{ $tag_location[$cur_gel_num][$cur_lane_num] = $cur_value; }
					else { push @read_error_message, "Line $line_i: Missing a value for Tag location.  This is a mandatory field when Tag type is specified."; }
				}
			}
			
			#ph - not mandatory
			if(defined $columns_found{"ph"})
			{
				$cur_value = $cur_values[$columns_found{"ph"}];
				if($cur_value)
				{
					if($cur_value =~ /^[0-9\.\s]+$/ && $cur_value > 0 && $cur_value <= 14)
					{ $ph[$cur_gel_num][$cur_lane_num] = $cur_value; }
					else
					{ push @read_error_message, "Line $line_i: Ph is not in the correct format."; }
				}
			}
			
			#notes - not mandatory
			if(defined $columns_found{"notes"})
			{
				$cur_value = $cur_values[$columns_found{"notes"}];
				if($cur_value)
				{ $notes[$cur_gel_num][$cur_lane_num] = $cur_value; }
			}
			
			#salt, buffer, detergent, other
			foreach my $cur_column (keys %ORDERED_COLUMNS)
			{
				my $reagent_i = 0; 
				foreach (@{$columns_found{$cur_column}})
				{#for each Salt/Buffer/Detergent/Other:
					
					$cur_value = $cur_values[$_];
					if($cur_value)
					{
						if(${$valid_reagents{$cur_column}}{lc $cur_value}) { ${$reagents{$cur_column}}[$cur_gel_num][$cur_lane_num][$reagent_i][0] = ${$valid_reagents{$cur_column}}{lc $cur_value}; }
						else { push @read_error_message, "Line $line_i: The column $cur_column has an unrecognized value, $cur_value - to suggest a new value be added for $cur_column, please email the site administrator."; }
			
						#salt concentration
						$cur_value = $cur_values[$_+1];
						if($cur_value =~ /^[0-9\.\s]+$/)
						{
							${$reagents{$cur_column}}[$cur_gel_num][$cur_lane_num][$reagent_i][1] = $cur_value;
							
							#salt unit
							$cur_value = $cur_values[$_+2];
							if($cur_value)
							{
								my $orig = $cur_value;
								$cur_value = lc($cur_value);
								$cur_value =~ s/\s+//g;
						
								if($REAGENT_AMT_UNITS{$cur_value}) #use value of hash, corrects for no spaces - to keep consistency in database (see definition in Common.pm)
								{
									${$reagents{$cur_column}}[$cur_gel_num][$cur_lane_num][$reagent_i][1] =
										convert_to_mM(${$reagents{$cur_column}}[$cur_gel_num][$cur_lane_num][$reagent_i][1], $cur_value);
									
									${$reagents{$cur_column}}[$cur_gel_num][$cur_lane_num][$reagent_i][2] = $REAGENT_AMT_UNITS{$cur_value};
								} 
								else
								{ push @read_error_message, "Line $line_i: $cur_column unit, $orig invalid."; }	
							}
							else
							{ push @read_error_message, "Line $line_i: $cur_column unit is missing."; }
						}
						else
						{ push @read_error_message, "Line $line_i: $cur_column concentration is missing or invalid."; }
						$reagent_i++;
					}
				}
			}
		}
		
		#stop & return if there is any errors while reading in the lines of the file...
		if(@read_error_message) { die ""; } #break through eval to return	
		
		# per gel validation:
		# (gel_num is the number of gels found in the file)
		
		@valid_lane_numbers = ();
		for(my $i = 0; $i < $gel_num; $i++)
		{
			if(!$num_lanes[$i])
			{
				# Total # of lanes on gel  - must be present atleast once per gel
				push @read_error_message, "Missing Total # of lanes on gel for gel $gel_file_names[$i].";
			}
			else
			{
				if($lanes_count[$i] > $num_lanes[$i])
				{#can't have more lanes than 'Total # lanes on gel', can have less because of blank lanes
					push @read_error_message, "Too many lanes for gel $gel_file_names[$i].  It does not match Total # of lanes on gel ($num_lanes[$i]).";
				}
				
				$valid_lane_numbers[$i] = ();
				foreach (keys %{$lanes_found[$i]})
				{#'Lane # on gel' must be from 1 to 'Total # lanes on gel', if it's outside that range give error
					if($_ <= 0 || $_ > $num_lanes[$i])
					{
						push @read_error_message, "Lane # on gel must be in the range from 1 to Total # of lanes on gel for gel $gel_file_names[$i].";
					}
					#add this lane number to the list of existing lane numbers
					push @{$valid_lane_numbers[$i]}, $_;
				}
				#sort for when we increment through the lanes
				@{$valid_lane_numbers[$i]} = sort {$a <=> $b} @{$valid_lane_numbers[$i]};
			}
		}
		
		#stop & return if there is any errors in gel/lane numbering
		if(@read_error_message) { die ""; }	
		
		# mass ladder for calibration - must be present atleast once per gel
		for(my $i = 0; $i < $gel_num; $i++)
		{
			my $found_mass_cal = 0;
			
			foreach(@{$valid_lane_numbers[$i]})
			{
				if($#{$mass_ladders[$i][$_]} >= 0)
				{ $found_mass_cal = 1; }
			}
			if(!$found_mass_cal) { push @read_error_message, "Mass ladder not found for gel $gel_file_names[$i].  Atleast one mass calibration lane is required for each gel."; }
		}
		
		##########
		#get the gel iteration ready so that first call to read_gel/read_lane goes to first gel/lane
		$num_gels = $gel_num;
		$current_gel_index = -1;
		$current_lane_index = -1;

	}; #end eval block
	
	if($@ || @read_error_message)
	{
		if($@ && $@ !~ /^Died at/) { unshift @read_error_message, $@; }
		close(GELIN);
		if($dbh) { $dbh->disconnect(); }
		return 0;
	}
	
    close(GELIN);
	$dbh->disconnect();
	return 1;
}

sub validate_protein_name
{#given protein systematic name, first check local DB, then if not found go online to verify.
	my $name = $_[0];
	my @dbs = Biochemists_Dream::Protein_DB -> search(Species => $species, { order_by => 'Priority' });
	foreach (@dbs)
	{
		my $db_id = $_ -> get('Id');
		my $db_name = $_ -> get('Name');
		my @proteins;
		if(($db_name eq 'RefSeq' || $db_name eq 'GenBank') && $name !~ /\.[0-9]+$/)
		{	
			#if no version number given for name, allow for it in the database:
			my $like_name = $name . '.' . '%';
			@proteins = Biochemists_Dream::Protein_DB_Entry -> search_like(Protein_DB_Id => $db_id, Systematic_Name => $like_name);
			my $max_version = 0; my $max_version_id;
			foreach my $prot (@proteins)
			{
				#find the latest version
				my $cur_name = $prot -> get('Systematic_Name');
				if($cur_name =~ /\.([0-9]+)$/)
				{
					my $cur_version = $1;
					if($max_version < $cur_version)
					{
						$max_version = $cur_version;
						$max_version_id = $prot -> get('Id');
					}
				}
			}
			if($max_version > 0)
			{
				#found the protein in the db - return the Id
				$_[1] = $max_version_id;
				$_[0] .= '.' . $max_version;
				return 1; #return positive value, indicates found in DB and it is the protein PK from table
			}
			else
			{#no version (for gene ID)
				@proteins = Biochemists_Dream::Protein_DB_Entry -> search_like(Protein_DB_Id => $db_id, Systematic_Name => $name);
				if($#proteins >= 0)
				{
					#found the protein in the db - return the Id
					$_[1] = $proteins[0] -> get('Id'); 
					return 1; #return positive value, indicates found in DB and it is the protein PK from table
				}
			
			}
		}
		else
		{
			@proteins = Biochemists_Dream::Protein_DB_Entry -> search(Protein_DB_Id => $db_id, Systematic_Name => $name);
			if($#proteins >= 0)
			{
				#found the protein in the db - return the Id
				$_[1] = $proteins[0] -> get('Id'); 
				return 1; #return positive value, indicates found in DB and it is the protein PK from table
			}
		}
	}
	
	#didn't find it in DB, go to online db's
	foreach (@dbs)
	{
		my $db_id = $_ -> get('Id');
		my $db_name = $_ -> get('Name');
		
		#call protein validator package
		
		my $common_name; my $version = "";
		if(Biochemists_Dream::ProteinNameValidator::validate($db_name, $name, $species, $common_name, $version))
		{
			$_[1] = $db_id;
			$_[2] = $common_name;
			
			if($version)
			{#add version number to end of protein name - it will only have a value if db is RefSeq and if 
			 #the version number was missing from the protein name in the data file
				$_[0] .= '.' . $version;
			}
			
			return -1; #indicates found
		}
	}
	
	return 0; #indicates not found, error
}

sub load_validation_tables_from_db
{
	foreach (keys %VALIDATION_COLS_TABLES)
	{
		my $sth = $dbh -> prepare("SELECT Name FROM $VALIDATION_COLS_TABLES{$_}");
		$sth -> execute();
		
		my %valid_names;
		
		while(my @row = $sth->fetchrow_array)
		{
			my $name = lc($row[0]);
			$valid_names{$name} = 1;
		}
		
		$validation_tables{$_} = \%valid_names;
		
	}
	
	foreach (keys %ORDERED_COLUMNS)
	{
		my $sth = $dbh -> prepare("SELECT Id, Name, Short_Name FROM Reagent WHERE Reagent_Type='$_'");
		$sth -> execute();
	
		my %cur_valid_reagents;
		while(my @row = $sth->fetchrow_array)
		{
			my $name = lc($row[1]);
			my $sh_name = lc($row[2]);
			$cur_valid_reagents{$name} = $row[0];
			$cur_valid_reagents{$sh_name} = $row[0];
		}
		$valid_reagents{$_} = \%cur_valid_reagents;
		
	}
}
	
sub get_gel_file_name
{
	return $gel_file_names[$current_gel_index];
}

sub gel_gel_file_name_orig
{
	return $gel_file_names_orig{$gel_file_names[$current_gel_index]};
}

sub get_num_lanes
{
	return $num_lanes[$current_gel_index];
}

sub get_mass_ladder
{#if empty list returned, then it is not a mass cal lane (no mass ladder)
 #else array of masses is returned
	return \@{$mass_ladders[$current_gel_index][$current_lane_index]};
}

sub get_qty_std_data
{#if empty list returned, then it is not a qty cal lane (no mass ladder)
 #else array of quantity cal. lane information, [0] - Qty Std Name, [1] - Qty Std Amt, [2] - Qty Std Units, [3] - Qty Std Mass, is returned
	return \@{$qty_std_data[$current_gel_index][$current_lane_index]};
}

sub get_ph
{
	return $ph[$current_gel_index][$current_lane_index];
}

sub get_protein_sys_name
{
	return $protein_name[$current_gel_index][$current_lane_index];
}

sub get_protein_common_name
{
	return $protein_common_name[$current_gel_index][$current_lane_index];
}

sub get_protein_id_in_db
{#returns false if protein not found in local DB else returns the ID of the Protein_DB_Entry column that matched
	return $protein_id_in_db[$current_gel_index][$current_lane_index];
}

sub get_protein_db_id_in_db
{#returns false if protein not found in online db or if online DB not checked (if get_protein_id_in_db has a value, then protein was found in local DB first
 #and online db was not checked), else returns the ID of the protein DB where the protein was found
	return $protein_db_id_in_db[$current_gel_index][$current_lane_index];
}

sub get_tag_location
{
	return $tag_location[$current_gel_index][$current_lane_index];
}

sub get_tag_type
{
	return $tag_type[$current_gel_index][$current_lane_index];
}

sub get_antibody
{
	return $antibody[$current_gel_index][$current_lane_index];
}

sub get_over_expressed
{
	return $over_expressed[$current_gel_index][$current_lane_index];
}

sub get_other_capture
{
	return $other_capture[$current_gel_index][$current_lane_index];
}

sub get_notes
{
	return $notes[$current_gel_index][$current_lane_index];
}

sub get_single_reagent_flag
{
	return $single_reagent_flag[$current_gel_index][$current_lane_index];
}

sub get_salts
{#returned array contains the Salts from the data file: at each position is an array w/ 3 elements -
#pos. 0 contains Salt Name, pos. 1 contains Salt Conc. and pos. 2 contains Salt Unit
#also, if no Salts, returned array will be an empty list
	return \@{${$reagents{'salt'}}[$current_gel_index][$current_lane_index]};
}

sub get_buffers
{
	return \@{${$reagents{'buffer'}}[$current_gel_index][$current_lane_index]};
}

sub get_detergents
{
	return \@{${$reagents{'detergent'}}[$current_gel_index][$current_lane_index]};
}

sub get_other_reagents
{
	return \@{${$reagents{'other'}}[$current_gel_index][$current_lane_index]};
}

sub add_reagent_header_error_msg
{
	my $next_col_name = shift;
	my $msgs_ref = shift;
	
	$next_col_name =~ s/ concentration//;
	$next_col_name =~ s/ unit//;
	
	push @read_error_message, "There was a problem reading the $next_col_name reagent headers in the file.  The headers for each $next_col_name reagent: $next_col_name, $next_col_name concentration, $next_col_name unit, must be together and in the exact order shown in the template.";
}

sub reset_gels
{#resets back to start of gel list
	$current_gel_index = -1;
	$current_lane_index = 0;
}

sub read_gel
{#returns 0 if we are at the end of the gels
	$current_gel_index++;
	if($current_gel_index == $num_gels) { return 0; }
	
	#advance to first lane index that is present
	$current_lane_index = -1; #$valid_lane_numbers[$current_gel_index][0];
	
	return 1;
}

sub reset_lanes
{#resets back to start of lane list
	if($current_gel_index > -1 && $current_gel_index < $num_gels) 
	{ $current_lane_index = $valid_lane_numbers[$current_gel_index][0]; }
	else { $current_lane_index = 0; }
}

sub read_lane
{#returns 0 if we are at the end of the lanes
	my $found = 0;
	foreach (@{$valid_lane_numbers[$current_gel_index]})
	{
		if ($_ > $current_lane_index) { $current_lane_index = $_; $found = 1; last; }
	}
	if (!$found) { return 0; }
	
	return 1;
}

sub get_lane_index
{
	return $current_lane_index;
}

END { ; } # module clean-up code here (global destructor)

1; # don't forget to return a true value from the file