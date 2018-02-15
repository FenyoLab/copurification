#!/usr/bin/perl

use warnings;
use strict;
use File::Util;

our $action_string = 'ContactList,LanesReport,OpenPublicView,LaneGrouping,Login,LoginPage,FAQ,HowTo,About,Contact,Home,SearchPublicGels,Choose Reagents,Set Ranges,Search,Search User,Logout,CreateAccount,Create Account,Search My Gels,Choose Reagent User,Set Ranges User,Add Project,Upload,Delete,ViewProject,Add Experiment,ViewExperiment,Make Public,MyProcedures,View / Edit,Create Procedure,Add MS Data,Del MS Data,Edit,DeleteFile,Cancel,Save Changes';
our $mode_string = 'MESSAGE,Home,LOGIN,CREATE USER,USER CREATED,SEARCH,SEARCH 2,SEARCH 3,PUBLIC VIEW SEARCH,PUBLICVIEW SEARCH 2,PUBLICVIEW SEARCH 3,FAQ,HowTo,About,Contact,Home,MESSAGE,PROJECT,EXPERIMENT,QUERY,QUERY2,QUERY3,USER,USER UPDATED,PROCEDURES,FRAME1,FRAME2,FRAME3,PUBLIC1,PUBLIC2,PRIVATE';

our %ALLOWED_HTML_PARAM_NAMES = ('action' => $action_string,
	'submit' => $action_string,
	'frame' => '1,2,3,1p,2p,3p',
	'mode' => $mode_string,
	'Text' => '^[A-Za-z0-9\:\.\,\@\s]+$',
	'email' => '^[A-Za-z0-9\@\.\_\-\+\s]+$',
	'password' => "-PASSWORD-", 			# password can have any characters.  DO NOT ESCAPE, it will be sent to DB after encryption so no SQL injection possibility
	'type' => 'PUBLIC,PRIVATE',
	'IdList' => '^[0-9\,\s]+$',
	'protein' => '-TEXT-', 				# allows special chars, must be escaped for SQL!
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
	'ms_search_engine_for_band' => 'Xtandem,XTandem,SEQUEST,Mascot,MSGFplus',
	'mass_spect_file_for_band' => "-FILENAME-", 
	'ms_protein_name' => '^[A-Za-z0-9\.\_]+$', 								
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
	'users' => '^[A-Za-z0-9\-\'\.\,\s]+$', 		# allows special chars, must be escaped for SQL!  											
	'user_ids' => '^[0-9\s]+$',
	'switch_color' => '^[A-Za-z\s]+$',
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
	'Cur_Systematic_Name_For_Band' => '^[A-Za-z0-9\.\_]+$', 					
	'Turn_On_MS_Input' => 'Yes,No',
	'Band_Popup_Error_Message' => '^[A-Za-z0-9\:\.\,\s]+$',
	'Gel_Id_for_Popup' => '^[0-9\s]+$',
	'ms_search_engine' => 'Xtandem,XTandem,SEQUEST,Mascot,MSGFplus',
	'mass_spect_file' => "-FILENAME-", 
	'Protein_Id_for_Rollover' => '^[0-9\s]+$',
	'current_species' => '^[A-Za-z\s]+$',
	'list_include_Salt' => '^[A-Za-z0-9\(\)\-\,\s]+$', 								
	'list_include_Buffer' => '^[A-Za-z0-9\(\)\-\,\s]+$',
	'list_include_Detergent' => '^[A-Za-z0-9\(\)\-\,\s]+$',
	'list_include_Other' => '^[A-Za-z0-9\(\)\-\,\s]+$');

sub make_sql_safe_str
{
    #This function REMOVES the following characters: \x00, \n, \r, \, ', " and \x1a.
    
    my $input = shift;
    $input =~ s/'//;
    $input =~ s/"//;
    $input =~ s/\n//;
    $input =~ s/\r//;
    $input =~ s/\\//;
    $input =~ s/\x00//;
    $input =~ s/\x1a//;
    
    return $input;
}

sub validate
{
    #check param name and value and returned escaped value OR if invalid return 0
    my $param=shift;
    my $value=shift;
    
    if (!$value) { return (1,''); } #allow for empty value
    
    if (defined $ALLOWED_HTML_PARAM_NAMES{$param})
    {
        my $code = $ALLOWED_HTML_PARAM_NAMES{$param};
        my $first_char = substr($code, 0, 1);
        my $last_char = substr($code, -1, 1);
        if ($first_char eq '^' && $last_char eq '$')
        { #it's a regex indicating the allowed string
            
            if ($value =~ /$code/)
            {#valid, generate safe value (shouldn't be needed), and return
                return (1,make_sql_safe_str($value)); 
            }
            else
            {#invalid
                #open(my $f, '>>', "$BASE_DIR/$DATA_DIR/input_validation_report.txt") || die "Failed to open file in param_check, Please contact support\@copurification.org.";
                #print $f "Not valid: \'$param\' \'$value\'\n\n";
                #close $f;
                return (0,0);
            }
        }
        elsif($first_char eq '-' && $last_char eq '-')
        { #it's -TEXT-, -PASSWORD- or -FILENAME-
            if($code eq '-TEXT-')
            {#allow any chars for text (?)
                return (1,make_sql_safe_string($value)); # important that the safe version is used for SQL
            }
            elsif($code eq '-PASSWORD-')
            {#allow any chars for password (?)
                return (1,$value); # no changing of password, it won't be sent to SQL, it is encoded first
            }
            elsif($code eq '-FILENAME-')
            {
                return (1,make_sql_safe_str(escape_filename($value))); # might as well check for valid file name as well
            } 
        }
        else
        { #it's a comma separated list of valid values
            my @valid_values = split(',', $code);
            foreach my $valid_value (@valid_values)
            {
                if ($value eq $valid_value)
                {
                    return (1,make_sql_safe_str($value)); #shouldn't be necessary here, but just to be safe
                }
            }
            #if reach here, value is not valid
            #open(my $f, '>>', "$BASE_DIR/$DATA_DIR/input_validation_report.txt") || die "Failed to open file in param_check, Please contact support\@copurification.org.";;
            #print $f "Not valid: \'$param\' \'$value\'\n\n";
            #close $f;
            return (0,0);
        }
    }
    else
    {	
        #open(my $f, '>>', "$BASE_DIR/$DATA_DIR/input_validation_report.txt") || die "Failed to open file in param_check, Please contact support\@copurification.org.";
        #print $f "Not valid: \'$param\' \'$value\' (unkown parameter)\n\n";
        #close $f;
        return (0,0);
    }
}

sub param_check
{
    #throws exception if param or value is invalid
    #else returns value and sql_escaped value
    #except when called with no args then just returns param()
    if (scalar(@_) > 0)
    {
	my $param_name = $_[0];
        my $is_array = 0;
        if (scalar(@_) > 1)
        {
            #2nd input tells whether return val is an array, if it is absent, assume scalar
            if ($_[1] != 0)
            {
                $is_array = 1;
            }
        }
        
        if ($is_array)
        {
            my @values=param($param_name);
            
            my @safe_values;
            my $invalid=0;
            #check each value in array before returning...
            foreach my $val (@values)
            {
                my ($is_valid,$safe_val) = validate($param_name, $val);
                if (!$is_valid)
                {
			#invalid input or value
			die "paramcheck() failed, Please contact support\@copurification.org.";
                }
                else
                {
                    push @safe_values, $safe_val;
                }
            }
	    return @safe_values;
        }
        else
        {
            my $val = param($param_name);
            my ($is_valid,$safe_val) = validate($param_name, $val);
            if (!$is_valid)
            {
                #invalid input or value
		die "paramcheck() failed, Please contact support\@copurification.org.";
            }
            else
            {
                return $safe_val;
            }
        }
    }
    else
    {
	my @values=param();
	return @values;
    }
}

sub param
{
    return 'Home';
}

my $ret_val = param_check('mode');

print $ret_val;
