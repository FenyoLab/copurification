#!/usr/bin/perl
#    (Biochemists_Dream::Common) Common.pm - provides global variables, functions useful to other modules of the program
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

use strict;
#use warnings;

package Biochemists_Dream::Common; # assumes Some/Module.pm

BEGIN {

require Exporter;

# set the version for version checking
our $VERSION = 1.00;

# Inherit from Exporter to export functions and variables
our @ISA = qw(Exporter);

# Functions and variables which are exported by default
#our @EXPORT = qw(func1 func2);
our @EXPORT = qw($DATA_DIR $SETTINGS_FILE $EXP_DATA_FILE_NAME_ROOT $GEL_DATA_FILE_NAME_ROOT $LADDER_FILE_NAME_ROOT $PROCESS_GELS_LOG_FILE_NAME 
		 $GEL_ERROR_LOG $BASE_DIR %ALLOWED_HTML_PARAM_HEADERS %ALLOWED_HTML_PARAM_NAMES %ALLOWED_EXP_PROC_FILE_TYPES %ALLOWED_GEL_DETAILS_FILE_TYPES $IMAGEMAGICK_DIR
		 $WKHTMLTOPDF_DIR $HOSTNAME %ALLOWED_GEL_FILE_TYPES %REAGENT_AMT_UNITS %QUANTITY_STD_UNITS $LANE_OUTPUT_FILE_FORMAT $FIND_LANES_TEMP_DIR read_settings
		 getConfig convert_to_mM);

# Functions and variables which can be optionally exported
#our @EXPORT_OK = qw($Var1 %Hashit func3);
our @EXPORT_OK = qw();

}

# exported package globals go here
#our $Var1 = '';
#our %Hashit = ();
our $DATA_DIR = "data_v2_0";
our $SETTINGS_FILE = "../settings.txt"; 
our $EXP_DATA_FILE_NAME_ROOT = "data";
our $GEL_DATA_FILE_NAME_ROOT = "gel";
our $LADDER_FILE_NAME_ROOT = "ladder";
our $PROCESS_GELS_LOG_FILE_NAME = "process_gels.log";
our $GEL_ERROR_LOG = "../lane_error_log.txt";
our $BASE_DIR = ""; 
our $IMAGEMAGICK_DIR = "";
our $WKHTMLTOPDF_DIR = "";
our $HOSTNAME = "";
our $LANE_OUTPUT_FILE_FORMAT = "#root#.lane-details.#i#.txt"; 
our $FIND_LANES_TEMP_DIR = "lanes_details"; #for find_lane_boundaries and find_lane_masses - not implemented yet!

#lists allowed gel file types - Q is if it can be Quantified
our %ALLOWED_EXP_PROC_FILE_TYPES = ('txt' => 1, 'rtf' => 1, 'doc' => 1, 'docx' => 1); 
our %ALLOWED_GEL_DETAILS_FILE_TYPES = ('txt' => 1, 'rtf' => 1, 'doc' => 1, 'xml' => 1, 'docx' => 1);
our %ALLOWED_GEL_FILE_TYPES = ('tif' => 'Q', 'png' => 'Q', 'jpg' => 'NQ', 'bmp' => 'Q');
our %REAGENT_AMT_UNITS = ('m' => 'mM', 'mm' => 'mM', 'um' => 'mM', 'µm' => 'mM', 'nm' => 'mM', 'pm' => 'mM', '% w/v' => '% w/v', '% v/v' => '% v/v', '%w/v' => '% w/v', '%v/v' => '% v/v', '%(w/v)' => '% w/v', '%(v/v)' => '% v/v');
our %QUANTITY_STD_UNITS = ('mg' => 1, 'µg' => 1, 'ng' => 1, 'pg' => 1, 'ug' => 1);
our $action_string = 'LinkTo,load_bands_for_lane,save_manual_bands,ContactList,LanesReport,OpenPublicView,LaneGrouping,Login,LoginPage,FAQ,HowTo,About,Contact,Home,SearchPublicGels,Choose Reagents,Set Ranges,Search,Search User,Logout,CreateAccount,Create Account,Search My Gels,Choose Reagents User,Set Ranges User,Add Project,Upload,Delete,ViewProject,Add Experiment,ViewExperiment,Make Public,MyProcedures,View / Edit,Create Procedure,Add MS Data,Del MS Data,Edit,DeleteFile,Cancel,Save Changes,Save MS Data';
our $mode_string = 'MESSAGE,Home,LOGIN,CREATE USER,USER CREATED,SEARCH,SEARCH 2,SEARCH 3,PUBLICVIEW SEARCH,PUBLICVIEW SEARCH 2,PUBLICVIEW SEARCH 3,FAQ,HowTo,About,Contact,Home,MESSAGE,PROJECT,EXPERIMENT,QUERY,QUERY2,QUERY3,USER,USER UPDATED,PROCEDURES,FRAME1,FRAME2,FRAME3,PUBLIC1,PUBLIC2,PRIVATE';
our %ALLOWED_HTML_PARAM_HEADERS = ('reagent_min' => '^[0-9\.]+$', 'reagent_max' => '^[0-9\.]+$');
our %ALLOWED_HTML_PARAM_NAMES = ('action' => $action_string,
	'submit' => $action_string,
	'frame' => '1,2,3,1p,2p,3p',
	'mode' => $mode_string,
	'Text' => '^[A-Za-z0-9\:\.\,\@\!\s]+$',
	'email' => '^[A-Za-z0-9\@\.\_\-\+\s]+$',
	'password' => "-PASSWORD-", 			# password can have any characters.  DO NOT ESCAPE, it will be sent to DB after encryption so no SQL injection possibility
	'type' => 'PUBLIC,PRIVATE',
	'IdList' => '^[0-9\,\s]+$',
	'protein' => '-TEXT-', 				# allows special chars, must be escaped for SQL!
	'systematic_name' => '-TEXT-',
	'species' => '^[A-Za-z\s]+$',
	'experiment_id' => '^[0-9\s]+$',
	'srf_choice' => 'multiple,nomult',
	'user_ids' => '^[0-9\s]+$',
	'projects_id' => '^[0-9\s]+$',
	'exps_id' => '^[0-9\s]+$',
	'reagents_exclude' => '^[0-9\,\s]+$',
	'reagents_include' => '^[0-9\,\s]+$',
	'ph_min' => '^[0-9\.\s]+$',
	'ph_max' => '^[0-9\.\s]+$',
	'search_type' => 'and,or',								
	'first_name' => '^[A-Za-z0-9\-\'\.\,\s]+$', 	# allows special chars, must be escaped for SQL! ^[A-Za-z0-9\-\'\.\,\s]+$
	'last_name' => '^[A-Za-z0-9\-\'\.\,\s]+$',	# allows special chars, must be escaped for SQL!
	'institution' => '-TEXT-',			# allows special chars, must be escaped for SQL!
	'title' => '-TEXT-',				# allows special chars, must be escaped for SQL!
	'orcid' => '^[A-Za-z0-9\-\.\:\/\s]+$',
	'project_name' => '-TEXT-',			# allows special chars, must be escaped for SQL!
	'project_description' => '-TEXT-',		# allows special chars, must be escaped for SQL!
	'project_parent_id' => '^[0-9\-\s]+$',
	'Experiment_Procedures' => "-FILENAME-",	# this can be a file name, will call fn. to check if valid
	'Gel_Details' => "-FILENAME-", 
	'experiment_checkbox' => '^[0-9\s]+$',
	'project_checkbox' => '^[0-9\s]+$',
	'Id' => '^[0-9\s]+$',
	'experiment_name' => '-TEXT-',			# allows special chars, must be escaped for SQL!
	'experiment_species' => '^[A-Za-z\s]+$',
	'experiment_description' => '-TEXT-',		# allows special chars, must be escaped for SQL!
	'experiment_procedure' => "-FILENAME-",         # this can be a file name, or '(none selected)', which should be ok since its a valid filename
	'gel_details' => "-FILENAME-",                  # this can be a file name, or '(none selected)', which should be ok since its a valid filename
	'experiment_data_file' => "-FILENAME-", 
	'gel_data_file' => "-FILENAME-", 
	'gels_public' => '^[0-9\s]+$',
	'page_type' => 'project,experiment,user,procedures,ms_lane_info',
	'band_or_lane' => 'band,lane',
	'update_or_delete' => 'Update,Delete',
	'Redisplay_Lane_Popup' => 'Yes,No',
	'ms_protein_id_method' => 'Mass Spec,mass spec,Western Blot,western blot,Other,other',
	'ms_search_engine_for_band' => 'Xtandem,XTandem,SEQUEST,Mascot,MSGFplus,Andromeda',
	'mass_spect_file_for_band' => "-FILENAME-", 
	'ms_protein_name' => '^[A-Za-z0-9\.\_\:\, ]+$', 								
	'Band_Id_for_Popup' => '^[0-9\s]+$',
	'Exp_Id_for_Popup' => '^[0-9\s]+$',
	'project_parent_id' => '^[0-9\s]+$',
	'experiment_id' => '^[0-9\s]+$',
	'SubDir' => 'Experiment_Procedures,Gel_Details',
	'File' => "-FILENAME-", 
	'shared_users' => '^[0-9\s]+$',
	'procedure_id' => '^[0-9\s]+$', 
	'projects_name' => '-TEXT-',								
	'projects_id' => '^[0-9\s]+$', 
	'exps_name' => '-TEXT-',								
	'exps_id' => '^[0-9\s]+$',
	'exps_proj_name' => '-TEXT-',
	'user' => '^[A-Za-z0-9\-\'\.\,\s]+$', 
	'users' => '^[A-Za-z0-9\-\'\.\,\s]+$', 		# allows special chars, must be escaped for SQL!  											
	'switch_color' => '^[A-Za-z0-9\s]+$',
	'Redisplay_Lane_Popup' => "Yes,No",
	'Gel_No_for_Popup' => '^[0-9\s]+$',
	'Lane_Order_for_Popup' => '^[0-9\s]+$',
	'Lane_Popup_Error_Message' => '^[A-Za-z0-9\:\.\,\s]+$',
	'Redisplay_Cur_Search_Engine' => 'Xtandem,XTandem,SEQUEST,Mascot,MSGFplus',
	'Redisplay_Cur_Results_File' => "-FILENAME-", 
	'Exp_Id_for_Popup' => '^[0-9\s]+$',
	'Redisplay_Band_Popup' => "Yes,No",
	'Band_Mass_for_Popup' => '^[0-9\.\s]+$',
	'Band_Id_for_Popup' => '^[0-9\s]+$',
	'Band_Id_for_File' => '^[0-9\s]+$',
	'Save_Lane_Order_for_Band_Processing' => '^[0-9\s]+$',
	'Cur_Systematic_Name_For_Band' => '-TEXT-', 			#this actually may contain common name		
	'Turn_On_MS_Input' => 'Yes,No',
	'Band_Popup_Error_Message' => '^[A-Za-z0-9\:\.\,\s]+$',
	'Gel_Id_for_Popup' => '^[0-9\s]+$',
	'ms_search_engine' => 'Xtandem,XTandem,SEQUEST,Mascot,MSGFplus,Andromeda',
	'mass_spect_file' => "-FILENAME-", 
	'Protein_Id_for_Rollover' => '^[0-9\s]+$',
	'current_species' => '^[A-Za-z\s]+$',
	'list_include_Salt' => '^[A-Za-z0-9\(\)\-\,\s]+$', 								
	'list_include_Buffer' => '^[A-Za-z0-9\(\)\-\,\s]+$',
	'list_include_Detergent' => '^[A-Za-z0-9\(\)\-\,\s]+$',
	'list_include_Other' => '^[A-Za-z0-9\(\)\-\,\s]+$',
	'list_exclude_Salt' => '^[A-Za-z0-9\(\)\-\,\s]+$', 								
	'list_exclude_Buffer' => '^[A-Za-z0-9\(\)\-\,\s]+$',
	'list_exclude_Detergent' => '^[A-Za-z0-9\(\)\-\,\s]+$',
	'list_exclude_Other' => '^[A-Za-z0-9\(\)\-\,\s]+$',
	'propogate_label' => '^[A-Za-z\_]*$',
	'verified_on_this_gel' => '^[A-Za-z]+$',
	'propogate_label_mass_range' => '^[0-9\.\s]+$',
	'snb_gel' => '^[0-9]+$',
	'snb_lanes_list' => '^[0-9\-]+$',
	'snb_tops_list' => '^[0-9\-]+$',
	'snb_heights_list' => '^[0-9\-]+$',
	'norm_img_str' => '^\-?n*$',
	'lane' => '^[0-9\s]+$',
	'exclude' => '^[0-1]$'
	);

# non-exported package globals go here
# (they are still accessible as $Some::Module::stuff)
#our @more = ();
#our $stuff = '';

# file-private lexicals go here, before any functions which use them
#my $priv_var = '';
#my %secret_hash = ();

# here's a file-private function as a closure,
# callable as $priv_func->();
# my $priv_func = sub {
# ...
# };

# make all your functions, whether exported or not;
# remember to put something interesting in the {} stubs
# sub func1 { ... }
# sub func2 { ... }

# Added by mgrivainis to remove leading and trailing whitespace
sub ltrim { shift =~ s/^\s+//r }
sub rtrim { shift =~ s/\s+$//r }
sub trim { ltrim rtrim shift }

sub getConfig
{
	open(SETTINGS_IN, "$SETTINGS_FILE") || return ('','','','');
	my $db_name=''; my $db_user=''; my $db_pwd='';
	while(<SETTINGS_IN>)
	{
		chomp();
		if(/^DBNAME=(.*)$/) { $db_name = trim($1); }
		elsif(/^DBUSER=(.*)$/) { $db_user = trim($1); }
		elsif(/^USERPWD=(.*)$/) { $db_pwd = trim($1); }
	}
	close(SETTINGS_IN);
	
	#return ('DBI:mysql:' . $db_name, $db_name, $db_user, $db_pwd);
	return ($db_name, $db_name, $db_user, $db_pwd);
}

sub read_settings
{
	open(SETTINGS_IN, "$SETTINGS_FILE") || return $! . " ($SETTINGS_FILE)";
	my $found = 0;
	while(<SETTINGS_IN>)
	{
		chomp();
		if(/^INSTALL_DIR=(.*)$/) { $BASE_DIR = trim($1); $found++; }
		elsif(/^ImageMagick=(.*)$/) { $IMAGEMAGICK_DIR = trim($1); $found++; }
		elsif(/^wkhtmltopdf=(.*)$/) { $WKHTMLTOPDF_DIR = trim($1); $found++; }
		elsif(/^HOSTNAME=(.*)$/) { $HOSTNAME = trim($1); $found++; }
	}
	close(SETTINGS_IN);
	if($found == 4) { return ""; }
	else { return "Information missing from settings file: $SETTINGS_FILE.\n"; }
}

sub convert_to_mM
{#units assumed to be in only lower case
	my $amt = shift;
	my $unit = shift;
	
	if($unit eq 'm')
	{
		$amt = $amt * 1000;
	}
	elsif($unit eq 'um' || $unit eq 'µm')
	{
		$amt = $amt / 1000;
	}
	elsif($unit eq 'nm')
	{
		$amt = $amt / 1000000;
	}
	elsif($unit eq 'pm')
	{
		$amt = $amt / 1000000000;
	}
	return $amt;
}

# this one isn't exported, but could be called directly
# as Some::Module::func3()
#sub func3 { ... }

END { ; } # module clean-up code here (global destructor)

1; # don't forget to return a true value from the file
