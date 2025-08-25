#!/usr/bin/perl
#    copurification.pl - this module handles the CGI for copurification.org and executes queries to the database for the Gel Search functions
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
#
#    Updated by Bart Aromando October 09, 2015
#    Added the processing of the Single Reagent Flag on loading experiment
#    Updated by Bart Aromando April 13, 2016
#    Added the processing of the Single Reagent Flag on Search
#    The proper term should be Single Reagent NOT Single Reagent  - I started to make changes
#    with regard to the visual / web page wording.  Must change the wording internally in code and database
#
#    Update - July 28, 2016
#    Includes: the following
#	1.	Mass Spec updates for entering protein data at the band and lane level
#	2.	Common Name is used for display only at this time while investigating protein database source
#	3.	It includes some cosmetic changes requested by John
#    It is essentially the version uploaded by Sarah Keegan on June 30, 2016

use lib "../lib";

#use warnings;
use strict;
#use DateTime;
use Biochemists_Dream::GelDB;
use CGI ':standard';
use Proc::Background;
use Biochemists_Dream::Common; 
use Biochemists_Dream::GelDataFileReader;
use Biochemists_Dream::GelDataFileReader qw(validate_protein_name);
#use Net::SMTP;
use File::Util;
#BA01252018 added for testing problems with this sub
use File::Util qw(escape_filename);
use File::Copy;


my $DEVELOPER_VERSION = 1;
#my $DEVELOPER_VERSION = 0;
my $DEVELOPER_LOGFILE = "dev_log.txt";

my $MAX_QUERY_RESULTS_FIELD_LENGTH = 75;

my $g_the_user;
my $g_user_login;
my $g_user_id;
my $g_frame;
my $g_header;

my $MAX_DISPLAY_LANES = 50;
my $MIN_GROUP_RATIO = 0; #.94;
my $SHOW_LADDER_LANES_IN_GROUP = 0;
my $PERFORM_GROUPING = 0;

my $SERVER_DOWN = 0;

STDOUT->autoflush(1);

eval #for exception handling
{
	#redirect stderr to a log file instead of letting it go to the Apache log file
	*OLD_STDERR = *STDERR;
	
	$g_header = 0; #set to true when display_title_header function is called - used in error page, to know whether to display header first or if it was already shown before exception thrown
	$g_user_login = 0;
	$g_the_user = undef;
	$g_user_id = 0;
	$g_frame = "";

	#check if user has logged in, and set user id
	$g_user_id = cookie('user_id');
	#$g_user_id = 2;

	#open settings file and read data directory:
	my $err = "";
	if($err = read_settings())
	{
		#we could be 'private' but just diplay public anyways for simplicity
		display_public_error_page("Cannot load settings file: $err.", 1);
		exit(0);
	}
	
	
	if($DEVELOPER_VERSION)
	{
		if(open(DEVEL_OUT, ">>$BASE_DIR/$DATA_DIR/$DEVELOPER_LOGFILE"))
		{
			*STDERR = *DEVEL_OUT;
		
			select(DEVEL_OUT);
			$|++; # autoflush DEVEL_OUT
			select(STDOUT);
			
			my $now_string = localtime;
			print DEVEL_OUT "Log opened: $now_string\n";
		}
		else
		{
			$DEVELOPER_VERSION = 0;
			open(STDERR, "NUL"); 
		}
		
	}
	else { open(STDERR, "NUL"); }    #*STDERR = 'NUL'; }
	
#	print header();
#	print <<START_HTML;	
#	<html lang="en">
#	<head>
#	<meta charset="utf-8">
#	<title>copurification.org</title>
#	</head>
#	<body style="background-color:white" style="margin:10;">
#	Hello World !!!!!!!
#	</body>
#	</html>
#	</table>
#START_HTML
#	exit(0);
	
	if ($SERVER_DOWN)
	{
		print header();
		print <<START_HTML;	
<html lang="en">
<head>
<meta charset="utf-8">
<title>copurification.org</title>
<link rel="stylesheet" href="../copurification-html/jquery-ui-1.10.1.custom.min.css">
<link rel="stylesheet" href="../copurification-html/header.css">
<script src="../copurification-html/jquery-1.9.1.js"></script>
<script src="../copurification-html/jquery-ui-1.10.1.custom.min.js"></script>
<script src="../copurification-html/jquery.MultiFile.pack.js"></script>
<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

  ga('create', 'UA-62498626-1', 'auto');
  ga('send', 'pageview');

</script>
</head>
<body style="background-color:white" style="margin:10;">
<table width="100%" align="center" ><tr bgcolor='lightgrey'><td><h2>copurification.org</h2></td></tr>
<tr bgcolor='#F5F5DC'><td><h2>Welcome to copurification.org!</h2>

<p>We curate images displaying protein co-purification banding patterns resulting from affinity capture followed by e.g. SDS-PAGE
and protein staining. We store the conditions of the experiment and link to the resulting banding patterns so purifications under
different conditions can be compared to one another.
<br><br>
<b>The server is down for maintenance from Wednesday, August 26 until Monday August 31, 2015.  Thank you for your patience.</b>
<br><Br><Br><br><br></p></td></tr>
</body>
</html>
</table>
START_HTML
	}
	else
	{
		if(!param_check())
		{#no posted data
			#if logged in, private view:
			if($g_user_id)
			{ display_frameset('', 'PRIVATE'); }
			else
			{ #if not logged in - public view:
				
				display_frameset('', 'PUBLIC', 'Home');
			}
		}
		else
		{#form data was posted: process the data
			#get param list:
			my @params = param_check();
			my $action = param_check('action');
			if(!$action) { $action = param_check('submit'); }
			$g_frame = param_check('frame') || '';
			
			## Special case for load_bands_for_lane ####
			if ($action eq 'load_bands_for_lane')
			{
				print header(-type => 'text/plain');
				if($DEVELOPER_VERSION) { print DEVEL_OUT "***Loading bands for lane.***\n"; }
				
				my $lane_id = param_check('lane');
				if($DEVELOPER_VERSION) { print DEVEL_OUT "load bands: lane=$lane_id.\n"; }
				
				# don't check for user login since this is also used by the public search results view
				# best way is to first check if public gel, and only if public gel then don't check for user (TODO)
                
				my $exclude = param_check('exclude');
				if($DEVELOPER_VERSION) { print DEVEL_OUT "load bands: exclude=$exclude.\n"; }
				
				my $lane = Biochemists_Dream::Lane -> retrieve("$lane_id");
				my @bands = $lane -> bands();
				
				my $ret_str="";
				if ($exclude)
				{
					my ($data_source, $db_name, $user, $password) = getConfig();
					my $dbh = DBI->connect($data_source, $user, $password, { RaiseError => 1, AutoCommit => 0 });
					my $sql = 'SELECT Protein_Id, MS_Search_Engine, Protein_Id_Method, MS_File_Suffix FROM band_protein WHERE Band_Id = ?';
					my $sth = $dbh->prepare($sql);
						
					foreach (@bands)
					{ # TO DO - finish this and don't forget "exclude" allowance for input params!!!
						my $band_id = $_ -> get ('Id'); 
						my $mass = $_ -> get('Mass') || "";
						my $amount = $_ -> get('Quantity') || "";
						my $st = $_ -> get('Start_Position');
						my $end = $_ -> get('End_Position');
						
						$sth->execute($band_id) or die "retrieve band error code: ", $DBI::errstr;
						my $row_count = $sth->rows;
						
						if ($row_count > 0)
						{
							$ret_str .= "$st,$end,"; 
						}
					}
				}
				else
				{
					foreach (@bands)
					{
						my $st = $_ -> get ('Start_Position');
						my $end = $_ -> get ('End_Position');
						$ret_str .= "$st,$end,"; 
					}
					
				}
				
				$ret_str=~s/,$//;
				if($DEVELOPER_VERSION) { print DEVEL_OUT "load bands return string (dict): '$ret_str'"; }
				print "$ret_str";
				exit(0);	
			}
			
			#### Special case for save_manual_bands ####
			if ($action eq 'save_manual_bands')
			{
				print header(-type => 'text/plain');
				if($DEVELOPER_VERSION) { print DEVEL_OUT "***Saving manual bands.***\n"; }
				if($g_user_id)
				{ #load user info.
					$g_user_login = 1;
					if(!login_the_user())
					{ #error page!
						print "ERROR: User log in failed.";
						if($DEVELOPER_VERSION) { print DEVEL_OUT "ERROR: User log in failed.\n"; }
						exit(1);
					}
		
					my $email = $g_the_user -> get('Email');
					if($DEVELOPER_VERSION) { print DEVEL_OUT "User info loaded for $email\n"; }
					
					
					my $gel_id = param_check('snb_gel');
					my $lanes_list = param_check('snb_lanes_list');
					my $tops_list = param_check('snb_tops_list');
					my $heights_list = param_check('snb_heights_list');
					my $norm_img_str = param_check('norm_img_str');
					
					if($DEVELOPER_VERSION)
					{ print DEVEL_OUT "SNB: gel=$gel_id, lanes_list=$lanes_list, tops_list=$tops_list, heights_list=$heights_list\n"; }
					
					my @lanes_list = split /\-/, $lanes_list;
					my @tops_list = split /\-/, $tops_list;
					my @heights_list = split /\-/, $heights_list;
					
					my $gel_obj = Biochemists_Dream::Gel -> retrieve($gel_id);
					my $exp_id = $gel_obj -> get('Experiment_Id');
					my $exp_obj = Biochemists_Dream::Experiment -> retrieve("$exp_id");
					
					my $gel_prefix = $gel_obj -> get('File_Id');
					$gel_prefix = "gel$gel_prefix";
					
					#first, obtain band mass by calling calc_new_bands_mass_amt.pl
					#must create new_bands.txt file in the Experiment directory
					my $exp_dir = "$BASE_DIR/$DATA_DIR/$g_user_id/Experiments/$exp_id";
					if(!open(BANDS_FILE, ">$exp_dir/$gel_prefix-new_bands.txt"))
					{
						if($DEVELOPER_VERSION) { print DEVEL_OUT "Could not create new bands file: $exp_dir/new_bands.txt.\n"; }
						print "Error: Could not create new bands file in Experiment directory.\n";
						exit(1);
					}
					else
					{
						my $i;
						print BANDS_FILE "lane_id\tmid\ttop\theight\n";
						for($i=0; $i<=$#lanes_list; $i++)
						{
							my $mid = $tops_list[$i] + int($heights_list[$i]/2);
							print BANDS_FILE "$lanes_list[$i]\t$mid\t$tops_list[$i]\t$heights_list[$i]\n";
						}
						close(BANDS_FILE);
						
						
						
						#CALL calc_new_bands_mass_amt.pl
						if ($DEVELOPER_VERSION) { print DEVEL_OUT qq!CALLING: "perl" "../finding_lane_boundaries/calc_new_bands_mass_amt.pl" "$exp_dir" "$gel_prefix" "calibration.txt" "new_bands.txt"\n!; }
						my $cmd_out = `"perl" "../finding_lane_boundaries/calc_new_bands_mass_amt.pl" "$exp_dir" "$gel_prefix" "calibration.txt" "$gel_prefix-new_bands.txt" 2>&1`;
						if($? >> 8 != 0) # exit value not 0, indicates error...
						{
							if($DEVELOPER_VERSION) {
								printf DEVEL_OUT "ERROR: command (calc_new_bands_mass_amt.pl) exited with value %d\n", $? >> 8, "\n";
								print DEVEL_OUT "$cmd_out\n";
							}
							printf "ERROR executing command calc_new_bands_mass_amt";
							exit(1);
						}
						else
						{
							my $i=0;
							#load band mass information from file output by calc_new_bands_mass_amt.pl
							if(!open(IN, "$exp_dir/$gel_prefix-new_bands.mass_and_amount.txt")) 
							{
								if ($DEVELOPER_VERSION) { print "Error: Could not open new bands file: '$exp_dir/$gel_prefix-new_bands.txt'.\n"; }
								print "Error: Could not open new bands file in Experiment directory.";
								exit(1);
							}
							else
							{
								
								my $line=<IN>;
								while($line=<IN>)
								{
									$line =~ s/\r\n//g;
									chomp($line);
									print DEVEL_OUT "line='$line'\n";
									if ($line=~/^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)/)
									{
										my $lane_id=$1;
										my $y_pos=$2;
										my $top=$3;
										my $height=$4;
										my $mass=$5;
										my $err=$6;
										
										print DEVEL_OUT "vars=$lane_id $y_pos $top $height $mass $err\n";
										
										my $bottom=$top+$height;
										
										$mass = sprintf("%.2f", $mass);
										if($err>0) { sprintf("%.2f", $err); }
										else { $err=undef; }
										
										my $band = Biochemists_Dream::Band -> insert({Lane_Id => $lane_id,
																			  Mass => $mass,
																			  Mass_Error => $err,
																			  Start_Position => $top,
																			  End_Position => $bottom});
										$i++;
									}
								}
								close(IN);
								
								#print "SUCCESS: $i bands added for gel..";
								display_experiment_results($exp_id, $exp_obj, $norm_img_str);
								
								if($DEVELOPER_VERSION) { print DEVEL_OUT "SUCCESS: $i bands added for gel $gel_id.\n"; }
								exit(0);
							}
						}
					}
				}
                else
				{
					print "ERROR: No user logged in.";
					if($DEVELOPER_VERSION) { print DEVEL_OUT "ERROR: No user logged in.\n"; }
					exit(1);
				}
            }
			#### Special case for save_manual_bands ####
            
	
			if($g_user_id)
			{ #load user info.
				$g_user_login = 1;
				if(!login_the_user())
				{ #error page!
					display_public_error_page("User login failed (cookie invalid, $g_user_id).", 1);
				}
	
				my $email = $g_the_user -> get('Email');
				if($DEVELOPER_VERSION) { print DEVEL_OUT "User info loaded for $email\n"; }
			}
			
			if($g_frame eq '3')
			{#display frame 3 - title header
				if($g_user_login) { display_frame3(); }
				else
				{
					display_public_error_page("Error loading frame...", 1);
				}
				
				exit(0);
			}
			if($g_frame eq '1')
			{#display frame 1 - project tree
				if($g_user_login) { display_frame1(); }
				else
				{
					display_public_error_page("Error loading frame...", 1);
				}
				
				exit(0);
			}
			if ($g_frame eq '1p') #frame 1p - header of public page
			{
				display_frame1p();
				exit(0);
			}
			if ($g_frame eq '2p') #frame 2p - 
			{
				my $mode = param_check('mode');
				if ($mode)
				{
					if ($mode eq 'MESSAGE')
					{
						my $msg = param_check('Text');
						display_frame2p($mode, $msg);
					}
					else { display_frame2p($mode); }
					
					
				}
				else
				{
					if ($g_user_id)
					{
						display_private_error_page("Error loading frame...");
					}
					else
					{
						display_public_error_page("Error loading frame...", 1);
					}
				}
				exit(0);
			}
			
			if(!$action)
			{#no action, at the home page
				if($g_frame eq '2')
				{#display frame 2 - the root main page (add a project to root) OR user login screen
					if($g_user_login) { display_frame2('PROJECT', 0, -1); }
					else
					{
						display_public_error_page("Error loading frame...", 1);
					}
					
				}
				else
				{
					if ($g_user_id)
					{
						display_private_error_page("Error loading frame...");
					}
					else
					{
						display_public_error_page("Error loading frame...", 1);
					}
				}
				exit(0);
			}
	
			if ($action eq 'ContactList')
			{
				#save to a file, the email address
				my $email = param_check('email');
				my $msg = '';
				if ($email)
				{
					my $res = save_to_contact_list($email);
					if($res) { $msg = 'Thank you!  Your email has been submitted to our contact list.' }
					else { $msg = 'Sorry - there was a problem when submitting your email address.'; }
				}
				else
				{
					$msg = 'Sorry - there was a problem when submitting your email address.';
				}
				
				display_frameset('', 'PUBLIC', 'MESSAGE', $msg);
				display_footer();
				
			}
			elsif($action eq "LanesReport")
			{
				my $MAX_DISPLAY_LANES_ON_PAGE = 5;
				
				my $type = param_check('type'); #PUBLIC or PRIVATE
				
				#get the lanes
				my $lanes_str = param_check('IdList');
				my $protein_name = param_check('protein');
				my $species = param_check('species');
				my $sys_name = param_check('systematic_name');
				my @lanes_list = split('-',$lanes_str);
				
				my $cur_num_lanes = 0; 
				my @lanes_to_display=(); my %reagents_to_display; my @users_to_display=(); my @exps_to_display=();  my @projects_to_display=();
				my @ph_to_display=(); my @exp_proc_files_to_display=();
				my @gel_details_files_to_display=(); my @img_tags_to_display=(); my @html_file_names=(); my $page_number = 1; my $lane_i = 0;
				my @over_exp_to_display = (); my @tag_type_to_display = (); my @tag_loc_to_display = ();
				my @antibody_to_display = (); my @other_cap_to_display = (); my @notes_to_display = (); 
				my @single_reagent_flag_to_display=(); my @elution_method_to_display=(); my @elution_reagent_to_display=();
				my @lanes = Biochemists_Dream::Lane -> retrieve_from_sql( qq { Id IN ($lanes_str) } ); 
				foreach my $lane (@lanes)
				{
					my $lane_id = $lane -> get("Id");
					my $lane_order = $lane -> get("Lane_Order");
					push @lanes_to_display, $lane_id;
						
					my @lane_reagents = $lane -> lane_reagents;
					foreach my $lane_reagent (@lane_reagents)
					{
						my $amt = $lane_reagent -> get("Amount");
						$amt =~ s/0+$//; $amt =~ s/\.$//;
						my $units = $lane_reagent -> get("Amount_Units");
						my $reagent = $lane_reagent -> Reagent_Id;
						my $type = $reagent -> get("Reagent_Type");
						my $chem = $reagent -> get("Name");
						if(defined $reagents_to_display{$lane_id}{$type})
						{
							$reagents_to_display{$lane_id}{$type} = "$reagents_to_display{$lane_id}{$type}, $amt $units $chem";
						}
						else { $reagents_to_display{$lane_id}{$type} = "$amt $units $chem"; }
					}
					
					my $gel = $lane -> Gel_Id;
					my $gel_id = $gel -> get('Id');
					my $experiment = $gel -> Experiment_Id;
					my $project = $experiment -> Project_Id;
					my $user = $project -> User_Id;
					my $exp_proc_file = $experiment -> get('Experiment_Procedure_File');
					my $gel_details_file = $experiment -> get('Gel_Details_File');
					
					my $gel_file_id = $gel -> get("File_Id");
					my $experiment_id = $gel -> get("Experiment_Id");
					my $user_id = $user -> get('Id');
					
					if ($type eq 'PUBLIC')
					{
						my $fname = $user -> get('First_Name');
						my $lname = $user -> get('Last_Name');
						push @users_to_display, "$lname, $fname";
					}
					else
					{
						push @exps_to_display, $experiment -> Name;
						push @projects_to_display, $project -> Name;
					}
					
					if ($exp_proc_file)
					{#should have one since the gel is public!
						$exp_proc_file = qq!<a href="http://$HOSTNAME/copurification/$user_id/Experiment_Procedures/$exp_proc_file" target="_blank">$exp_proc_file</a>!;
					}
					else { $exp_proc_file = '(none)'; }
					
					if ($gel_details_file)
					#should have one since the gel is public!
					{
						$gel_details_file = qq!<a href="http://$HOSTNAME/copurification/$user_id/Gel_Details/$gel_details_file" target="_blank">$gel_details_file</a>!;
					}
					else { $gel_details_file = '(none)'; }
					
					push @exp_proc_files_to_display, $exp_proc_file;
					push @gel_details_files_to_display, $gel_details_file;
			
					my $ph = $lane -> get('Ph');
					$ph =~ s/0+$//; $ph =~ s/\.$//;
					push @ph_to_display, $ph;
					
					my $over_exp = $lane -> get('Over_Expressed');
					if (defined $over_exp)
					{ 
						if ($over_exp)
						{ push @over_exp_to_display, 'Yes'; }
						else { push @over_exp_to_display, 'No'; }
					}
					else { push @over_exp_to_display, '-'; }
					
					my $field = $lane -> get('Tag_Type');
					if (defined $field) { push @tag_type_to_display, $field; }
					else { push @tag_type_to_display, '-'; }
					
					$field = $lane -> get('Tag_Location');
					if (defined $field) { push @tag_loc_to_display, $field; }
					else { push @tag_loc_to_display, '-'; }
					
					$field = $lane -> get('Antibody');
					if (defined $field) { push @antibody_to_display, $field; }
					else { push @antibody_to_display, '-'; }
					
					$field = $lane -> get('Other_Capture');
					if (defined $field) { push @other_cap_to_display, $field; }
					else { push @other_cap_to_display, '-'; }
					
					$field = $lane -> get('Notes');
					if (defined $field) { push @notes_to_display, $field; }
					else { push @notes_to_display, '-'; }
					
					$field = $lane -> get('Elution_Method');
					if (defined $field) { push @elution_method_to_display, $field; }
					else { push @elution_method_to_display, '-'; }
					
					$field = $lane -> get('Elution_Reagent');
					if (defined $field) { push @elution_reagent_to_display, $field; }
					else { push @elution_reagent_to_display, '-'; }
					
					$field = $lane -> get('Single_Reagent_Flag');
					if (defined $field) 
					{ 
						#translate the column into english
						if ($field == 0) {$field = "Multiple"} else {$field = "Single"};
						push @single_reagent_flag_to_display, $field; 
					}
					else { push @single_reagent_flag_to_display, '-'; }
							
					my @cal_lanes = Biochemists_Dream::Lane -> search(Gel_Id => $gel_id, Quantity_Std_Cal_Lane => 1);
					my $units = "";
					if($#cal_lanes >= 0) { $units = $cal_lanes[0] -> get('Quantity_Std_Units'); }
					
					my $gel_root = 'gel' . $gel_file_id;
					#use middle image - medium darkness
					my $img_tag = qq!<img src="../$user_id/Experiments/$experiment_id/$gel_root.lane.$lane_order.n.png" >!;
					push @img_tags_to_display, $img_tag;
					
					#add output where the masses/quanitty are displayed next to bands!?
					
					$cur_num_lanes++;
					if(($cur_num_lanes == $MAX_DISPLAY_LANES_ON_PAGE) || ($lane_i == $#lanes))
					{
						my $fname;
						if ($type eq 'PUBLIC')
						{
							$fname = save_query_results('PUBLIC', $protein_name, $species, $sys_name, \@lanes_to_display,
														\%reagents_to_display,
										\@img_tags_to_display, \@ph_to_display, \@users_to_display, \@exp_proc_files_to_display,
										\@gel_details_files_to_display, \@over_exp_to_display, \@tag_type_to_display,
										\@tag_loc_to_display, \@antibody_to_display, \@other_cap_to_display,
										\@notes_to_display, \@single_reagent_flag_to_display, \@elution_method_to_display,
										\@elution_reagent_to_display, $page_number); #save html to a file(s) in Reports dir
						}
						else
						{
							$fname = save_query_results('PRIVATE', $protein_name, $species, $sys_name, \@lanes_to_display,
														\%reagents_to_display,
										\@img_tags_to_display, \@ph_to_display, \@exps_to_display, \@projects_to_display,
										\@exp_proc_files_to_display,
										\@gel_details_files_to_display, \@over_exp_to_display, \@tag_type_to_display,
										\@tag_loc_to_display, \@antibody_to_display, \@other_cap_to_display,
										\@notes_to_display, \@single_reagent_flag_to_display, \@elution_method_to_display,
										\@elution_reagent_to_display, $page_number); #save html to a file(s) in Reports dir
						}
						
						$fname =~ s/^/"/; #put quotes around it for when we make the system call...
						$fname =~ s/$/"/;
						push @html_file_names, $fname;
						
						#clear the data structures
						undef @lanes_to_display; undef @img_tags_to_display; undef @ph_to_display; undef @users_to_display;
						undef @single_reagent_flag_to_display; undef @elution_method_to_display; undef @elution_reagent_to_display;
						undef @exp_proc_files_to_display; undef @gel_details_files_to_display; undef %reagents_to_display;
						@lanes_to_display=(); @img_tags_to_display=(); @ph_to_display=(); @users_to_display=();
						@exp_proc_files_to_display=(); @gel_details_files_to_display=(); %reagents_to_display=();
						undef @over_exp_to_display; undef @tag_type_to_display; undef @tag_loc_to_display;
						undef @antibody_to_display; undef @other_cap_to_display; undef @notes_to_display;
						@over_exp_to_display = (); @tag_type_to_display = (); @tag_loc_to_display = ();
						@antibody_to_display = (); @other_cap_to_display = (); @notes_to_display = ();
						undef @exps_to_display; undef @projects_to_display;
						@exps_to_display = (); @projects_to_display = (); @single_reagent_flag_to_display=();
						@elution_method_to_display=(); @elution_reagent_to_display=();
						
						$page_number++;
						$cur_num_lanes = 0;
					}
					$lane_i++;
				}
				
				#convert file(s) to pdf
				my $html_files_str = join(' ', @html_file_names);
				my $time = localtime;
				$time =~ s/:/ /g;
				my $rnum = rand();
				$rnum =~ s/^0.//;
				#print DEVEL_OUT "*****$BASE_DIR/$DATA_DIR/Reports/$protein_name-$species-$time-$lane_i-Lanes.$rnum.pdf\n";
				#print DEVEL_OUT "*****$html_files_str\n";
				my $pdf_file_name = "$BASE_DIR/$DATA_DIR/Reports/$protein_name-$species-$time-$lane_i-Lanes.$rnum.pdf";
				my $sys_ret = system(qq!"$WKHTMLTOPDF_DIR/wkhtmltopdf" $html_files_str "$pdf_file_name"!);
				if($sys_ret != 0)
				{
					print DEVEL_OUT "Error: wkhtmltopdf failed to create pdf file.\n";
				}
				
				#delete the html files 
				foreach my $file (@html_file_names)
				{
					$file =~ s/"//g;
					#unlink("$file");
				}
			
				#return page with js that redirects to pdf file 'download'
				$pdf_file_name =~ s/^.+[\\\/]([^\\\/]+\.pdf$)/$1/; #get only file name not dirs
				display_report_download_page($pdf_file_name);
				
				#add code to check for errors!!!
				
			}
			elsif($action eq "LinkTo")
			{
				my $species = param_check("species");
				my $protein = param_check("protein");
				my $user = param_check("user");
				
				display_frameset_for_link($species, $protein, $user);
			}
			elsif($action eq "OpenPublicView")
			{
				display_frame2p('PUBLICVIEW SEARCH');
	
			}
			elsif($action eq "LaneGrouping")
			{
				#get the gel id's for the analysis, or use all gels in the experiment?
				#my @ids = param_check('gels_public',1);
				my $exp_id = param_check('experiment_id');
				my $exp = Biochemists_Dream::Experiment -> retrieve($exp_id);
				my $user_id = $exp -> Project_Id -> User_Id;

				if(1) # (!(-e "$BASE_DIR/$DATA_DIR/$g_user_id/Experiments/$exp_id/lane_grouping.html"))
				{
					
					my $exp_name = $exp -> Name;
					
					#get gels, we will need the gel file name
					my @gels = Biochemists_Dream::Gel -> search(Experiment_Id => $exp_id);
					my %gel_files;
					foreach my $gel (@gels)
					{
						my $gel_id = $gel -> Id;
						my $file_id = $gel -> File_Id;
						$gel_files{$gel_id} = "$BASE_DIR/$DATA_DIR/$user_id/Experiments/$exp_id/gel$file_id";
					}
					
					#gel all lanes in this experiment and sort by captured protein id
					my @lanes = Biochemists_Dream::Lane -> retrieve_from_sql(
						qq{ Gel_Id IN (SELECT Id FROM Gel WHERE Experiment_Id = $exp_id) ORDER BY Captured_Protein_Id } );
					my %lanes_to_group;
					my %lane_conditions;

					foreach my $lane (@lanes)
					{#organize lanes by cap protein id
						#my $lane_id = $lane -> Id;
						my $cap_protein_id = $lane -> Captured_Protein_Id;
						my $gel_id = $lane -> Gel_Id;
						my $lane_num = $lane -> Lane_Order;
						if ($cap_protein_id)
						{#skip calibration lanes (cap protein id == null)
							push @{$lanes_to_group{"$cap_protein_id"}{"$gel_id"}}, "$lane_num";
						}
						else
						{
							if ($SHOW_LADDER_LANES_IN_GROUP)
							{
								push @{$lanes_to_group{"-1"}{"$gel_id"}}, "$lane_num";
							}
							
						}
						
						#organize/store the conditions for this lane, so that we may show it in the html created below
						my @lane_reagents = $lane -> lane_reagents;
						
						#my @lane_reagents = Biochemists_Dream::Lane_Reagents -> retrieve_from_sql( qq{ Lane_Id = $lane_id } );
						foreach my $lane_reagent (@lane_reagents)
						{
							my $amount = $lane_reagent -> Amount;
							my $units = $lane_reagent -> Amount_Units;
							my $reagent = $lane_reagent -> Reagent_Id;
							my $name = $reagent -> Short_Name;
							my $type = $reagent -> Reagent_Type;
							$gel_files{$gel_id} =~ /(gel\d+)$/;
							push @{$lane_conditions{$1}{"$lane_num"}{"$type"}}, "$amount $units $name";
						}
						
					}
					if ($SHOW_LADDER_LANES_IN_GROUP)
					{
						foreach my $cap_protein_id (keys %lanes_to_group)
						{
							if ($cap_protein_id ne "-1")
							{
								#add ladder lanes in with this set
								foreach my $gel_id (keys %{$lanes_to_group{"-1"}})
								{
									foreach my $lane_num (@{$lanes_to_group{"-1"}{$gel_id}})
									{
										push @{$lanes_to_group{"$cap_protein_id"}{"$gel_id"}}, "$lane_num";
									}
								}
								last;
							}
							
						}
					}
					
					my $error_string = "";
					#run lane grouping for each cap protein id
					foreach my $cap_protein_id (keys %lanes_to_group)
					{
						if ($cap_protein_id eq "-1") { next; }
						
						my $lanes_to_run = "";
						foreach my $gel_id (keys %{$lanes_to_group{$cap_protein_id}})
						{
							$lanes_to_run .= ('"' . $gel_files{$gel_id} . '" ');
							my $lanes = join(' ', @{$lanes_to_group{$cap_protein_id}{$gel_id}});
							$lanes_to_run .= ( '"' . $lanes . '" ');
						}
						
						my $cmd_out = `"perl" "../finding_lane_boundaries/calculate_lane_scores.pl" "$BASE_DIR/$DATA_DIR/$user_id/Experiments/$exp_id" "$cap_protein_id.lane_scores.txt" $lanes_to_run 2>&1`;	
						if ( $? == -1 )
						{
						    $error_string = qq?ERROR 1: command failed (calculate_lane_scores.pl): $!\nCommand: "../finding_lane_boundaries/calculate_lane_scores.pl" "$BASE_DIR/$DATA_DIR/$user_id/Experiments/$exp_id" "$cap_protein_id.lane_scores.txt" $lanes_to_run?;
						}
						elsif($? >> 8 != 0) # exit value not 0, indicates error...
						{
						    $error_string = sprintf("ERROR 2: command (calculate_lane_scores.pl) exited with value %d\n", $? >> 8);
						    $error_string .= qq?$cmd_out\nCommand: "../finding_lane_boundaries/calculate_lane_scores.pl" "$BASE_DIR/$DATA_DIR/$user_id/Experiments/$exp_id" "$cap_protein_id.lane_scores.txt" $lanes_to_run?;
						}
					}
					if(open(OUT, ">$BASE_DIR/$DATA_DIR/$user_id/Experiments/$exp_id/lane_grouping.html"))
					{
						if ($error_string)
						{
							print OUT "<HTML><HEAD><TITLE>copurification.org</TITLE><link rel='stylesheet' href='/copurification-html/main2.css'></HEAD><BODY>";
							print OUT "<p>Error: <pre>$error_string</pre></p>";
							print OUT "</BODY></HTML>";
							close(OUT);
						}
						else
						{
							print OUT "<HTML><HEAD><TITLE>copurification.org</TITLE><link rel='stylesheet' href='/copurification-html/main2.css'></HEAD><BODY>";
							print OUT "<h1>Lane Clustering for Experiment '$exp_name'</h1>";
							#get results txt files and create image/html
							foreach my $cap_protein_id (keys %lanes_to_group)
							{
								if ($cap_protein_id eq "-1") { next; }
								print OUT "<H2>Captured Protein: ";
								my $protein = Biochemists_Dream::Protein_DB_Entry -> retrieve($cap_protein_id);
								print OUT $protein -> Common_Name;
								print OUT " (";
								print OUT $protein -> Systematic_Name;
								print OUT ")</H2>";
								
								my $html = create_lane_grouping_html($exp_id, $user_id, "$cap_protein_id.lane_scores.txt", \%lane_conditions);
								print OUT $html;
							}
							print OUT "</BODY></HTML>";
							close(OUT);
						}
					}
					else
					{
						;
					}
				}
				
				#load html from file and return it
				print header();
				if(open(IN, "$BASE_DIR/$DATA_DIR/$user_id/Experiments/$exp_id/lane_grouping.html"))
				{	
					while(<IN>) { print; }
				}
				else
				{
					;
				}
	
			}
			elsif($action eq "Login")
			{#attempt to log in the user
				my $email = param_check('email');
				my $password = param_check('password');
	
				$g_user_id = validate_user($email, $password);
				
				
				if($DEVELOPER_VERSION) { print DEVEL_OUT "g_user_id = $g_user_id\n"; }
				if($g_user_id)
				{#login successful
					#set cookie
					my @cookies;
					my $cookie = cookie(-name=>'user_id', -value=>"$g_user_id");
					push @cookies, $cookie;
	
					login_the_user();
	
					#go to private view
					display_frameset(\@cookies, 'PRIVATE');
				}
				else
				{#login unsuccessful, reload login page w/ error message
					display_public_error_page("Sorry, the login failed.", 1);
				}
			}
			elsif($action eq "LoginPage")
			{
				if(!$g_user_login)
				{
					display_frame2p('LOGIN');
				}
				else
				{
					display_frameset('', 'PRIVATE');
				}
			}
			elsif($action eq "FAQ")
			{#display the faq page...
				if(!$g_user_login)
				{
					display_frame2p('FAQ');
				}
				else
				{
					display_frame2('FAQ');
				}				
	
			}
			elsif($action eq "HowTo")
			{#display the howto page...
				if(!$g_user_login)
				{
					display_frame2p('HowTo');
				}
				else
				{
					display_frame2('HowTo');
				}				
	
			}
			elsif($action eq "About")
			{#display the about page...
				if(!$g_user_login)
				{
					display_frame2p('About');
				}
				else
				{
					display_frame2('About');
				}				
	
			}
			elsif($action eq "Contact")
			{#display the Contact page...
				if(!$g_user_login)
				{
					display_frame2p('Contact');
				}
				else
				{
					display_frame2('Contact');
				}				
	
			}
			elsif($action eq "Home")
			{#display the Contact page...
				
				display_frame2p('Home');
			}
			elsif($action eq "SearchPublicGels")
			{
				if(!$g_user_login)
				{
					display_frame2p('SEARCH');
				}
				else
				{
					display_frameset('', 'PUBLIC', 'PUBLICVIEW SEARCH');
				}
			}
			elsif($action eq "Choose Reagents")
			{#next button from search input page
				#gather inputs and show amount ranges of selected reagents
				if(!$g_user_login)
				{
					display_frame2p('SEARCH 2');
				}
				else
				{
					display_frame2p('PUBLICVIEW SEARCH 2');
				}
				
			}
			elsif($action eq "Set Ranges")
			{#next button from search input page
				#gather inputs and show amount ranges of selected reagents
				if(!$g_user_login)
				{
					display_frame2p('SEARCH 3');
				}
				else
				{
					display_frame2p('PUBLICVIEW SEARCH 3');
				}
				
			}
			elsif($action eq "Search" || $action eq "Search User")
			{#perform the public gel search and display results
				
				if ($action eq "Search User" && !$g_user_login)
				{
					display_public_error_page("Invalid action for public user. ('Search User').", 1);
					exit(0);
				}
				
				my $err_str = "";
				#get search parameters:
				my $species = param_check('species');
				my $protein_str = param_check('protein');
				
				my $protein_name = $protein_str;
				$protein_name =~ s/^([0-9]+) //;
				my $protein = $1;
				
				#get srf chosen field and filter lanes if no multiple
				my $srf_choice = param_check('srf_choice');
				
				my $pdbentry = Biochemists_Dream::Protein_DB_Entry->retrieve($protein);
				my $sys_name = $pdbentry->get("Systematic_Name");
				
				my $where_clause;
				my @users; my $user_id_list;
				if ($action eq "Search")
				{
					#turn user ids into comma separated lists for sql statment
					@users = param_check('user_ids',1);
					$user_id_list = "";
					foreach (@users) { if($_ ne -1) { $user_id_list .= "$_, "; } }
					$user_id_list =~ s/, $//;
				}
				else
				{
					my @projs_id = param_check('projects_id',1);
					my @exps_id = param_check('exps_id',1);
					if (!@exps_id)
					{ $where_clause = "(project_id in (" . join(',', @projs_id) . "))"; }
					elsif(!@projs_id)
					{ $where_clause = "(id in (" . join(',', @exps_id) . "))"; }
					else
					{ $where_clause = "(id in (" . join(',', @exps_id) . ") or project_id in (" . join(',', @projs_id) . "))"; }
				}
				
				#load the exclude reagent constrains from the query form
				my $reagent_exclude_ids = param_check('reagents_exclude');
				while ($reagent_exclude_ids =~ /,\s*$/)
				{
					$reagent_exclude_ids =~ s/\s*,\s*$//;
				}
				
				#load the include reagent constraints from the query form
				my $reagent_ids = param_check('reagents_include');
				my @reagent_include_ids = split /,/, $reagent_ids;
				my %reagent_constraints;
				foreach my $id (@reagent_include_ids)
				{
					#for each possible unit type:
					foreach my $unit (values %REAGENT_AMT_UNITS)
					{
						#get min/max for current reagent id/amount, if exists:
						my $min_param = "reagent_min_$id" . "_$unit";
						my $min = param_check($min_param);
						if(defined $min && $min ne '')
						{
							my $max_param = "reagent_max_$id" . "_$unit";
							my $max = param_check($max_param);
							
							if($min !~ /[0-9\.]+/ || $max !~ /[0-9\.]+/ || $min < 0 || $max < 0 || $min > $max)
							{
								$err_str = "Please check your search parameters.  Reagent min/max values are invalid. ($min) ($max)";
								last;
							}
							${$reagent_constraints{$id}{$unit}}[0] = $min;
							${$reagent_constraints{$id}{$unit}}[1] = $max;
						}
					}
				}
				
				#load ph constraint 
				my $min_ph = param_check('ph_min');
				my $max_ph = param_check('ph_max');
				if($min_ph !~ /[0-9\.]+/ || $max_ph !~ /[0-9\.]+/ || $min_ph < 0 || $max_ph < 0 || $min_ph > $max_ph)
				{ $err_str = "Please check your search parameters.  pH min/max values are invalid."; }
				
				#load INCLUDE reagents search type:
				my $search_type = param_check('search_type');
				if (!$search_type) { $search_type = 'and'; }
				
				my @lanes_to_display = (); my %reagents_to_display = (); my @users_to_display = (); my @ph_to_display = (); my @exp_proc_files_to_display = ();
				my @gel_details_files_to_display = (); my @img_tags_to_display = (); my @checks_to_display = (); my $hidden_to_display = "";
				my $image_map_html = ""; my @over_exp_to_display = (); my @tag_type_to_display = (); my @tag_loc_to_display = ();
				my @antibody_to_display = (); my @other_cap_to_display = (); my @notes_to_display = (); 
				my @single_reagent_flag_to_display = (); my @elution_method_to_display=(); my @elution_reagent_to_display=();
				my @exps_to_display = (); my @projects_to_display = (); my @citations_to_display = (); my @lane_ms_to_display=(); my @xrefs_to_display = ();
				my $num_to_display = 0; my $max_over = 0;
				if(!$err_str)
				{
					my @lanes; my @experiments; 
					if ($action eq 'Search')
					{#public search
						if($user_id_list)
						{#if user id (s) selected, first get experiments that match that user (and species, if selected)
							@experiments = Biochemists_Dream::Experiment -> retrieve_from_sql(
								qq{ Project_Id IN (SELECT Id FROM Project WHERE User_Id IN ($user_id_list)) AND Species = '$species' } ); 
						}
						else
						{
							@experiments = Biochemists_Dream::Experiment -> search(Species => $species);
						}
					}
					else
					{#private search
						#get exps based on project id and exp id from input, only for the selected species
						@experiments = Biochemists_Dream::Experiment -> retrieve_from_sql(qq{ $where_clause AND Species = '$species' } ); 
					}
					
					if($#experiments < 0) { $err_str = 'No lanes found.'; }
					else
					{
						#create list of experiment ids
						my $exp_id_list;
						foreach (@experiments) { my $id = $_ -> get('Id'); $exp_id_list .= "$id, "; }
						$exp_id_list =~ s/, $//;
						
						if ($action eq 'Search')
						
						{#get lanes that come from public gel, match tagged protein and come from experiments selected above (for user/species):
							@lanes = Biochemists_Dream::Lane -> retrieve_from_sql(
								qq{ Gel_Id IN (SELECT Id FROM Gel WHERE Public = 1 AND Experiment_Id IN ($exp_id_list)) AND Captured_Protein_Id = $protein } );
						}
						
						else
						{
							@lanes = Biochemists_Dream::Lane -> retrieve_from_sql(
								qq{ Gel_Id IN (SELECT Id FROM Gel WHERE Experiment_Id IN ($exp_id_list)) AND Captured_Protein_Id = $protein } );
						}
						if($#lanes < 0) { $err_str = 'No lanes found.'; }
					}
		
					#gather lanes that match ALL include reagents
					foreach my $lane (@lanes)
					{
						#check ph
						my $ph = $lane -> get('Ph');
						if($ph < $min_ph || $ph > $max_ph) { next; }
						
						#####check srf and go to next
						# the srf on database is zero when there are multiple reagents
						# the srf_choice from web page is 'No' when mulitples are not included
						my $srf = $lane -> get('Single_Reagent_Flag');
						#   $srf_choice = param_check('srf_choice');
						#print DEVEL_OUT "SRF DB Flag: $srf\n";
						#print DEVEL_OUT "SRF Choice : $srf_choice\n";
						if($srf == 0 and $srf_choice eq 'nomult') { next; }
						
						my $lane_id = $lane -> get("Id");
						
						#check exclude reagents not present for lane
						if($reagent_exclude_ids=~/\w/)
						{
							my @lcs = Biochemists_Dream::Lane_Reagents -> retrieve_from_sql( qq{ Reagent_Id IN ($reagent_exclude_ids) AND Lane_Id = $lane_id } );
							if($#lcs >= 0) { next; }
						}
						
						#include reagents - both AND/OR cases
						my $match = 0; my $reagents_found = 0;
						foreach my $id (@reagent_include_ids)
						{
							my $reag_found = 0;
							foreach my $unit (keys %{$reagent_constraints{$id}})
							{
								my @lcs = Biochemists_Dream::Lane_Reagents -> retrieve_from_sql(
									qq{ Reagent_Id = $id AND Lane_Id = $lane_id AND Amount_Units = '$unit' AND Amount >= ${$reagent_constraints{$id}{$unit}}[0] AND Amount <= ${$reagent_constraints{$id}{$unit}}[1] } );
								if($#lcs >= 0)
								{ $reag_found = 1; last; }
								
							}
							if(!$reag_found)
							{
								if($search_type eq 'and') { last; } #a reagent not found, exit (must find all reagents)
							}
							else
							{
								if($search_type eq 'or') { $match = 1; last; } #only need to find one reagent
								else { $reagents_found++; }
							}
							
						}
						if($search_type eq 'and' && $reagents_found == scalar(@reagent_include_ids)) { $match = 1; }
						if($match)
						{#add this lane to display list, show its reagents, proteins, users, species
							$num_to_display++;
							if($num_to_display > $MAX_DISPLAY_LANES) { $max_over = 1; last; }
							
							my $lane_order = $lane -> get("Lane_Order");
							push @lanes_to_display, $lane_id;
							
							my @lane_reagents = $lane -> lane_reagents;
							foreach my $lane_reagent (@lane_reagents)
							{
								my $amt = $lane_reagent -> get("Amount");
								$amt =~ s/0+$//; $amt =~ s/\.$//;
								my $units = $lane_reagent -> get("Amount_Units");
								my $reagent = $lane_reagent -> Reagent_Id;
								my $type = $reagent -> get("Reagent_Type");
								my $chem = $reagent -> get("Name");
								if(defined $reagents_to_display{$lane_id}{$type})
								{
									$reagents_to_display{$lane_id}{$type} = "$reagents_to_display{$lane_id}{$type}, $amt $units $chem";
								}
								else { $reagents_to_display{$lane_id}{$type} = "$amt $units $chem"; }
							}
							
							my $gel = $lane -> Gel_Id;
							my $citation = $gel -> get('Citation');
							my $xref = $gel -> get('XRef');
							my $gel_id = $gel -> get('Id');
							my $experiment = $gel -> Experiment_Id;
							my $project = $experiment -> Project_Id;
							my $user = $project -> User_Id;
							my $exp_proc_file = $experiment -> get('Experiment_Procedure_File');
							my $gel_details_file = $experiment -> get('Gel_Details_File');
							
							my $gel_file_id = $gel -> get("File_Id");
							my $experiment_id = $gel -> get("Experiment_Id");
							my $user_id = $user -> get('Id');
							
							if ($action eq 'Search')
							{
								my $fname = $user -> get('First_Name');
								my $lname = $user -> get('Last_Name');
								push @users_to_display, "$lname, $fname";
							}
							else
							{
								push @exps_to_display, $experiment -> Name;
								push @projects_to_display, $project -> Name;
							}
							
							if ($citation)
							{
								#regex the PMID and make it into a link
                                if ($citation =~ /PMID:\s*(\d+)/i)
								{
									my $id = $1;
									$citation = "PMID: <a href='https://www.ncbi.nlm.nih.gov/pubmed/$id' target='_blank'>$id</a>";  
                                }
								# Handle DOI in the format 'DOI: ...'
								elsif ($citation =~ /DOI:\s*(\S+)/i) {
									my $doi = $1;
									$citation = "DOI: <a href='https://doi.org/$doi' target='_blank'>$doi</a>";
								}
                            }
							else { $citation='(none)'; }
							
							if ($xref)
							{
								# IntAct
                                if ($xref =~ /IntAct:\s*([0-9\-A-Za-z]+)/i)
								{
									my $id = $1;
									$xref = "IntAct: <a href='https://www.ebi.ac.uk/intact/search/do/search?searchString=imex:$id' target='_blank'>$id</a>";  
                                }
								# Pride
								elsif ($xref =~ /Pride:\s*(PXD\d+)/i) {
									my $id = $1;
									$xref = "PRIDE: <a href='https://www.ebi.ac.uk/pride/archive/projects/$id' target='_blank'>$id</a>";  
								}
								# MassIVE
								elsif ($xref =~ /MassIVE:\s*(PXD\d+)/i) {
									my $id = $1;
									$xref = "MassIVE: <a href='https://proteomecentral.proteomexchange.org/cgi/GetDataset?ID=$id' target='_blank'>$id</a>";  
								}
                            }
							else { $xref='(none)'; }
                            
							if ($exp_proc_file)
							{#should have one since the gel is public!
								$exp_proc_file = qq!<a href="/copurification/$user_id/Experiment_Procedures/$exp_proc_file" target="blank">$exp_proc_file</a>!;
							}
							else { $exp_proc_file = '(none)'; }
							
							if ($gel_details_file)
							#should have one since the gel is public!
							{
								$gel_details_file = qq!<a href="/copurification/$user_id/Gel_Details/$gel_details_file" target="blank">$gel_details_file</a>!;
							}
							else { $gel_details_file = '(none)'; }
							
							push @exp_proc_files_to_display, $exp_proc_file;
							push @gel_details_files_to_display, $gel_details_file;
							push @citations_to_display, $citation;
							push @xrefs_to_display, $xref;
					
							my $ph = $lane -> get('Ph');
							$ph =~ s/0+$//; $ph =~ s/\.$//;
							push @ph_to_display, $ph;
							
							my $over_exp = $lane -> get('Over_Expressed');
							if (defined $over_exp)
							{ 
								if ($over_exp)
								{ push @over_exp_to_display, 'Yes'; }
								else { push @over_exp_to_display, 'No'; }
							}
							else { push @over_exp_to_display, '-'; }
							
							my $field = $lane -> get('Tag_Type');
							if (defined $field) { push @tag_type_to_display, $field; }
							else { push @tag_type_to_display, '-'; }
							
							$field = $lane -> get('Tag_Location');
							if (defined $field) { push @tag_loc_to_display, $field; }
							else { push @tag_loc_to_display, '-'; }
							
							$field = $lane -> get('Antibody');
							if (defined $field) { push @antibody_to_display, $field; }
							else { push @antibody_to_display, '-'; }
							
							$field = $lane -> get('Other_Capture');
							if (defined $field) { push @other_cap_to_display, $field; }
							else { push @other_cap_to_display, '-'; }
							
							$field = $lane -> get('Notes');
							if (defined $field) { push @notes_to_display, $field; }
							else { push @notes_to_display, '-'; }
							
							$field = $lane -> get('Single_Reagent_Flag');
							if (defined $field) 
							{ 
								#translate the column into english
								if ($field == 0) {$field = "Multiple"} else {$field = "Single"};
								push @single_reagent_flag_to_display, $field; 
							}
							else { push @single_reagent_flag_to_display, '-'; }
							
							$field = $lane -> get('Elution_Method');
							if (defined $field) { push @elution_method_to_display, $field; }
							else { push @elution_method_to_display, '-'; }
							
							$field = $lane -> get('Elution_Reagent');
							if (defined $field) { push @elution_reagent_to_display, $field; }
							else { push @elution_reagent_to_display, '-'; }
							
							my @cal_lanes = Biochemists_Dream::Lane -> search(Gel_Id => $gel_id, Quantity_Std_Cal_Lane => 1);
							my $units = "";
							if($#cal_lanes >= 0) { $units = $cal_lanes[0] -> get('Quantity_Std_Units'); }
							
							my $gel_root = 'gel' . $gel_file_id;
							my $lane_search_engine = $lane -> get("MS_Search_Engine");
							my $lane_file_suffix = $lane -> get("MS_File_Suffix");
							my $ms_str='';
							if ($lane_search_engine and $lane_file_suffix)
							{
								my $fn = "/copurification/$user_id/Experiments/$experiment_id/$gel_root.lane.$lane_order.ms.$lane_file_suffix";
								if ((lc $lane_file_suffix) eq 'xml')
								{ $ms_str = qq!<a href="$fn" download="xml_file">$lane_search_engine</a>!; }
                                else
								{ $ms_str = qq!<a href="$fn" target="_blank">$lane_search_engine</a>!; }
                            }
							else
							{
								$ms_str = qq!(none)!; 
							}
							push @lane_ms_to_display, $ms_str;
							
							my $checkbox = qq!<input type='checkbox' name='check_lanes' value='$lane_id' />!;
							push @checks_to_display, $checkbox;
							
							my $hidden = qq!<input type='hidden' name='lane' id='$lane_id' value='on'/>!;
							$hidden_to_display .= $hidden;
							
							#imagemap masses to bands:
							my @bands = $lane -> bands;
							$image_map_html .= create_imagemap_html_for_search(\@bands, $lane_id, $units, $lane_order, $gel_file_id, $experiment_id, $user_id);
							
							my $img_tag = qq!<div id="lane_div_$lane_id">\
					                <div name="lane_image" ><img id="lane_image_$lane_id" class="lane_image" src="/copurification/$user_id/Experiments/$experiment_id/$gel_root.lane.$lane_order.png" usemap="#$lane_id"></div>\
									<div name="norm_lane_image" style="display:none"><img id="nlane_image_$lane_id" class="nlane_image" src="/copurification/$user_id/Experiments/$experiment_id/$gel_root.lane.$lane_order.n.png" usemap="#$lane_id"></div>\
									<div name="norm_lane_image2" style="display:none"><img id="n2lane_image_$lane_id" class="n2lane_image" src="/copurification/$user_id/Experiments/$experiment_id/$gel_root.lane.$lane_order.nn.png" usemap="#$lane_id"></div>!;
									
							if (-e "$BASE_DIR/$DATA_DIR/$user_id/Experiments/$experiment_id/$gel_root.lane.$lane_order.nnn.png")
							{
                                $img_tag .= qq!<div name="norm_lane_image3" style="display:none"><img id="n3lane_image_$lane_id" class="n3lane_image" src="/copurification/$user_id/Experiments/$experiment_id/$gel_root.lane.$lane_order.nnn.png" usemap="#$lane_id"></div></div>!;
                            }
							else
							{
								$img_tag .= qq!<div name="norm_lane_image3" style="display:none"><img id="n3lane_image_$lane_id" class="n3lane_image" src="/copurification/$user_id/Experiments/$experiment_id/$gel_root.lane.$lane_order.nn.png" usemap="#$lane_id"></div></div>!;
							}

							push @img_tags_to_display, $img_tag; 
						}
					}
				}
				
				if(!$err_str) 
				{
					if ($action eq 'Search')
					{
						display_query_results('PUBLIC', $protein_name, $species, $sys_name, \@lanes_to_display, \%reagents_to_display,
											  \@img_tags_to_display,
								$image_map_html, \@ph_to_display, \@users_to_display, \@exp_proc_files_to_display,
								\@gel_details_files_to_display, \@checks_to_display, $hidden_to_display,
								\@over_exp_to_display, \@tag_type_to_display, \@tag_loc_to_display, \@antibody_to_display,
								\@other_cap_to_display, \@notes_to_display, \@single_reagent_flag_to_display, 
								\@elution_method_to_display, \@elution_reagent_to_display, \@citations_to_display, \@xrefs_to_display,
								\@lane_ms_to_display, $max_over); 
					}
					else
					{
						display_query_results('PRIVATE', $protein_name, $species, $sys_name, \@lanes_to_display, \%reagents_to_display,
											  \@img_tags_to_display,
								$image_map_html, \@ph_to_display, \@exps_to_display, \@projects_to_display, \@exp_proc_files_to_display,
								\@gel_details_files_to_display, \@checks_to_display, $hidden_to_display,
								\@over_exp_to_display, \@tag_type_to_display, \@tag_loc_to_display, \@antibody_to_display,
								\@other_cap_to_display, \@notes_to_display, \@single_reagent_flag_to_display, 
								\@elution_method_to_display, \@elution_reagent_to_display, \@citations_to_display, \@xrefs_to_display,
								\@lane_ms_to_display, $max_over); 
					}
				}	
				else
				{
					if ($g_user_id)
					{
						display_private_error_page($err_str);
					}
					else
					{
						display_public_error_page($err_str);
					}
				}
			}
			elsif($action eq "Logout")
			{
				if($g_user_login)
				{
					#set cookie to 0
					my @cookies;
					my $cookie = cookie(-name=>'user_id', -value=>'0');
					push @cookies, $cookie;
	
					logout_the_user();
	
					#display_frameset(\@cookies, 'PUBLIC', 'SEARCH', ); #display public homepage
					display_frameset(\@cookies, 'PUBLIC', 'Home'); #display public homepage
				}
				else
				{
					display_frameset('', 'PUBLIC', 'Home');
				}
			}
			elsif($action eq "CreateAccount")
			{
				if(!$g_user_login)
				{
					display_frame2p('CREATE USER');
				}
				else
				{
					display_frameset('', 'PRIVATE');
				}
				
			}
			elsif($action eq "Create Account")
			{
				if($DEVELOPER_VERSION) { print DEVEL_OUT "In Create User\n"; }
				if(!$g_user_login)
				{
					my $error_str = "";
					my $email = ""; my $user_dir;
					local Biochemists_Dream::User -> db_Main -> { AutoCommit }; #turn off autocommit (in this block only)
					eval
					{
						#get the user params:
						my $first_name = param_check('first_name') || undef;
						my $last_name = param_check('last_name');
						my $institution = param_check('institution') || undef;
						my $title = param_check('title') || undef;
						my $orcid = param_check('orcid') || undef;
						$email = param_check('email');
						my $password = param_check('password');
	
						#to do ! validate the params in javascript!
	
						#first check for duplicate email (user already exists):
						my @users = Biochemists_Dream::User -> search(Email => $email);
						if($#users < 0)
						{ #email not found in db, create user
	
							#encrypt password for storing in the database
							my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
							my $crypt_password = crypt($password, $salt);
	
							my $new_user = Biochemists_Dream::User -> insert({First_Name => $first_name, Last_Name => $last_name, Title => $title, OrcID => $orcid, Institution => $institution, Email => $email, Password => $crypt_password, Validated => 1, });
							my $new_user_id = $new_user -> get('Id');
	
							#to do ! - add user validation by email
	
							#create the user's folder for experiment data, etc.
							#if(mkdir("/var/www/data_v2_0/1000/"))
							#{
							#	print DEVEL_OUT "DIR CREATED";
							#}
							#else { $error_str = " unable to create (/var/www/data_v2_0/1000/) - $!"; }
							if(mkdir("$BASE_DIR/$DATA_DIR/$new_user_id"))
							{
								$user_dir = "$BASE_DIR/$DATA_DIR/$new_user_id";
								if(mkdir("$BASE_DIR/$DATA_DIR/$new_user_id/Experiments"))
								{
									if(mkdir("$BASE_DIR/$DATA_DIR/$new_user_id/Experiment_Procedures"))
									{
										if(mkdir("$BASE_DIR/$DATA_DIR/$new_user_id/Gel_Details"))
										{
										}
										else { $error_str = " SRF
										      for new user ($BASE_DIR/$DATA_DIR/$new_user_id/Gel_Details) - $!"; }
									}
									else { $error_str = " Could not create directory for new user ($BASE_DIR/$DATA_DIR/$new_user_id/Experiment_Procedures) - $!"; }
								}
								else { $error_str = " Could not create directory for new user ($BASE_DIR/$DATA_DIR/$new_user_id/Experiments) - $!"; }
							}
							else { $error_str = " Could not create base directory for new user ($BASE_DIR/$DATA_DIR/$new_user_id) - $!"; }
	
						}
						else { $error_str = " A user with this email already exists."; }
					}; #end eval block
					if($@) { $error_str = $@; }
	
					if($error_str eq "")
					{
						display_frame2p('USER CREATED');
						if($DEVELOPER_VERSION) { print DEVEL_OUT "User created: $email\n"; }
					}
					else
					{ #delete the newly created user from the database, and the user directory
						Biochemists_Dream::User -> dbi_rollback;
	
						my $ret_err = "";
						if($user_dir) { $ret_err = delete_directory($user_dir); }
						if($ret_err) { $error_str .= ", $ret_err"; }
	
						display_public_error_page($error_str);
					}
				}
				else
				{
					display_frameset('', 'PRIVATE');
				}
			}
			elsif($g_user_login)
			{
				if($action eq 'Search My Gels')
				{#private gel search of logged in user, show query page 1
					#retrieve projects and experiments that were selected by the user 
					
					display_frame2('QUERY', 0, '', '');
					
				}
				elsif($action eq "Choose Reagents User")
				{#next button from search input page - private search
					#gather inputs and show amount ranges of selected reagents
					display_frame2('QUERY2', 0, '', '');
				}
				elsif($action eq "Set Ranges User")
				{#next button from search input page
					#gather inputs and show amount ranges of selected reagents
					display_frame2('QUERY3', 0, '', '');
					
				}
				elsif($action eq "Add Project") 
				{
					my $name = param_check('project_name') || '?'; #error case if no name given, must have project name...!add javascript to block this!
					my $desc = param_check('project_description') || undef; #let description column be NULL if user enters no description
					my $parent_id = param_check('project_parent_id');
					
					
					if(!$parent_id)
					{ #no parent, let it be NULL in the database (root project) and use current user as the project owner
						$parent_id = undef;
						#add a project with the given name, description, parent_id to the database
						my $new_project = Biochemists_Dream::Project -> insert({Name => $name, Description => $desc, Project_Parent_Id => $parent_id, User_Id => $g_user_id});
					} 
					else
					{ # get parent project owner for current project owner
						my $parent_project = Biochemists_Dream::Project->retrieve($parent_id);
						my $parent_user_id = $parent_project -> get("User_Id");
						
						#add a project with the given name, description, parent_id to the database
						my $new_project = Biochemists_Dream::Project -> insert({Name => $name, Description => $desc, Project_Parent_Id => $parent_id, User_Id => $parent_user_id});
					}
					
					#clear params...
					param('project_name', '');
					param('project_description', '');
	
					#return to project page or home page if parent_id is -1
					if($parent_id)
					{ display_frame2('PROJECT', 1, $parent_id); }
					else { display_frame2('PROJECT', 1, -1); }
				}
				elsif($action eq 'Upload')
				{
					#upload MIAPE-AC or GE file to users directory
					#if file already exists, replace it
					# *add JS warning on web page for user!! - also check if associated with Exps and warn!?
					
					my $err_str = '';
					my $sub_dir;
					my $remote_file;
					my $lw_fh = upload('Experiment_Procedures');
					if ($lw_fh) 
					{ 
						$remote_file = param('Experiment_Procedures');
						$remote_file = param_check_file_name('Experiment_Procedures',$remote_file); 
						$sub_dir = 'Experiment_Procedures'; 
					} # undef may be returned if it's not a valid file handle, e.g. file transfer interrupted by user
					elsif($lw_fh = upload('Gel_Details')) 
					{ 
						$remote_file = param('Gel_Details'); 
						$remote_file = param_check_file_name('Gel_Details',$remote_file); 
						$sub_dir = 'Gel_Details'; 
					}
					else { $err_str = "Error in file upload."; }
					
					#check that remote file extension is .txt, if not then return error message
					my $extension = $remote_file;
					if ($extension =~ s/^.*\.([^\.]+)$/$1/)
					{
						if ($sub_dir eq 'Experiment_Procedures')
						{
							if(!$ALLOWED_EXP_PROC_FILE_TYPES{lc $extension})
							{
								$err_str = 'File type not supported.';
							}
						}
						elsif($sub_dir eq 'Gel_Details')
						{
							if(!$ALLOWED_GEL_DETAILS_FILE_TYPES{lc $extension})
							{
								$err_str = 'File type not supported.';
							}
							
						}
						
					}
					else { $err_str = 'File type not supported.'; }
					
					if (!$err_str)
					{
						#check if local file exists and delete if necessary!
						#upload the data file
						my $local_fname = "$BASE_DIR/$DATA_DIR/$g_user_id/$sub_dir/$remote_file";
						#delete local file if it exists:
						if (-e $local_fname) { unlink($local_fname); }
						my $io_fh = $lw_fh -> handle; # Upgrade the handle to one compatible with IO::Handle:
						
						$local_fname =~ s/^(.*)\.[^\.]+$/$1/; #remove extension b/c function takes root of local file name and adds extension of uploaded file
						#$local_fname = lc $local_fname;
						$err_str = upload_file($remote_file, $io_fh, $local_fname);
						close($io_fh);
						if($err_str) { $err_str .= " (file upload)"; }
					}
					if($err_str)
					{
						display_frame2('PROCEDURES', 0, '', '', "There was an error in uploading '$remote_file': $err_str");
					}
					else { display_frame2('PROCEDURES', 0, '', '', "'$remote_file' has been successfully added to your file list."); }
				}
				elsif($action eq 'Delete')
				{
					#delete projects and experiments that were selected by the user
					my $parent_id = param_check('project_parent_id');
	
					#first, experiments
					my @ids_to_delete = param_check('experiment_checkbox',1);
					my $err_str = "";
	
					foreach my $id (@ids_to_delete)
					{
						#check if exp is owned by current user (to avoid deleting of shared projects)
						
						$err_str .= delete_experiment($id);
					}
	
					#next, projects
					@ids_to_delete = ();
					@ids_to_delete = param_check('project_checkbox',1);
	
					#sort by id (descending) so that subprojects will be deleted first
					my @sorted_ids = sort {$b <=> $a} @ids_to_delete;
	
					foreach my $id (@sorted_ids)
					{
						#delete the projects that were checked (all experiments and other projects in this project will be deleted also)
						#add javascript to warn the user!
						$err_str .= delete_project($id);
					}
	
					if($err_str eq "")
					{
						#return to project page or home page if parent_id is -1
						if($parent_id) { display_frame2('PROJECT', 1, $parent_id); }
						else { display_frame2('PROJECT', 1, -1); }
						#display_frame1();
					}
					else{ display_private_error_page($err_str); }
				}
				elsif($action eq 'ViewProject') #done frames
				{
					my $project_id = param_check('Id');
	
					#print out the project details page
					display_frame2('PROJECT', 0, $project_id);
	
				}
				elsif($action eq "Add Experiment")
				{
					my $err_str = ""; my $experiment_dir = ""; my $cur_user_id="";
					my $project_id = param_check('project_parent_id');
					my $id; my $new_experiment; #the new experiment and id
					my @new_proteins;
					#local Biochemists_Dream::Experiment -> db_Main -> { AutoCommit }; #turn off autocommit (in this block only)
					eval
					{
						my $name = param_check('experiment_name') || '?'; #error case if no name given, must have project name...
						my $species = param_check('experiment_species');
						my $desc = param_check('experiment_description') || undef; #let description column be NULL if user enters no description
						my $proc_file = param_check('experiment_procedure');
						if ($proc_file eq '(none selected)') { $proc_file = undef; } else { $proc_file = lc($proc_file); }
						my $gel_file = param_check('gel_details');
						if ($gel_file eq '(none selected)') { $gel_file = undef; } else { $gel_file = lc($gel_file); }
						
						my $project = Biochemists_Dream::Project->retrieve($project_id);
						$cur_user_id = $project -> get("User_Id");
						
						#add an experiment with the given name, description, project_id to the database
						$new_experiment = Biochemists_Dream::Experiment -> insert({Name => $name, Description => $desc, Species => $species, Project_Id => $project_id, Experiment_Procedure_File => $proc_file, Gel_Details_File => $gel_file});
						$id = $new_experiment -> get("Id");
						
						if($DEVELOPER_VERSION) { print DEVEL_OUT "Experiment created, id = $id\n"; }
						
						my $lw_fh = upload('experiment_data_file'); # undef may be returned if it's not a valid file handle, e.g. file transfer interrupted by user
						my $remote_file = param('experiment_data_file');
						$remote_file = param_check_file_name('experiment_data_file',$remote_file); 
						if (defined $lw_fh)
						{
							#upload the data file, create a directory for this experiment, and save the file there
							
							
							$experiment_dir = "$BASE_DIR/$DATA_DIR/$cur_user_id/Experiments/$id"; #the dir will be named w/ the primary key id
							if(mkdir($experiment_dir))
							{
								my $local_fname = "$experiment_dir/$EXP_DATA_FILE_NAME_ROOT"; #param_check('experiment_data_file');
								my $io_fh = $lw_fh -> handle; # Upgrade the handle to one compatible with IO::Handle:
								my $ext = "";
								
								if($DEVELOPER_VERSION) { print DEVEL_OUT "About to upload file: $remote_file, $local_fname.\n"; }
								#BA01252018 testing
								#print DEVEL_OUT "remote file:  $remote_file\n";
								$err_str = upload_file($remote_file, $io_fh, $local_fname, $ext);
								#BA01252018 testing
								#print DEVEL_OUT "extension after upload_file:  $ext\n";
								#if($DEVELOPER_VERSION) { print DEVEL_OUT "Exited from upload file.\n"; }
								
								close($io_fh);
								if($err_str) { $err_str .= " (file upload)"; }
								#BA01252018 testing
								#print DEVEL_OUT "extension:  $ext\n";
							
								if (lc $ext ne 'txt')
								{
									$err_str .= "Sample Descriptions file must be have .txt extension."; 
								}
								
							}
							else { $err_str = "Could not create directory for new experiment ($experiment_dir) - $!"; }
						}
						else { $err_str = "Could not upload Sample Descriptions file"; }
	
						#upload gel files and save to experiment directory
						my $gel_remote_fname_list = "";
						my $gel_id_fname_list = "";
						my $gel_ext_fname_list = "";
						if($err_str eq "")
						{
							my @remote_files = param_check('gel_data_file',1);
							if (@remote_files)
							{
								my $remote_file; my $i = 1;
								foreach $remote_file (@remote_files)
								{
									if ($remote_file)
									{
										my $local_fname = "$experiment_dir/$GEL_DATA_FILE_NAME_ROOT" . "$i";
										my $ext;
										my $remote_file_name = $remote_file;
										if($err_str = upload_file($remote_file_name, $remote_file, $local_fname, $ext))
										{ $err_str .= " (gel file upload)"; last; }
										close($remote_file);
											
										if(!defined $ALLOWED_GEL_FILE_TYPES{lc $ext})
										{
											my $ext_list = join ', ', keys %ALLOWED_GEL_FILE_TYPES;
											$err_str = "Unrecognized file type for gel file $remote_files[$i-1]. The allowed extensions are: $ext_list.";
											last;
										}
										my $remote_fname_root = $remote_file_name;
										$remote_fname_root =~ s/\.\w\w\w$//; #remove extension
										
										$gel_remote_fname_list .= "$remote_fname_root/";
										$gel_id_fname_list .= "$i/";
										$gel_ext_fname_list .= "$ext/";
										$i++;
									}
								}
								if ($i == 1)
								{
									$err_str = "No gel files uploaded";
								}
								
							}
							else { $err_str = "No gel files uploaded";  }
							
						}
						
						if($err_str eq "")
						{
								#create background process to run
								
								$err_str=call_new_experiment($id, "$BASE_DIR/$DATA_DIR/$cur_user_id/Experiments", $species, $gel_remote_fname_list, $gel_id_fname_list, $gel_ext_fname_list);
						}
					
					}; #end eval block
					if($@) { $err_str = $@; }
					
					#clear params...
					param('experiment_name', '');
					param('experiment_description', '');
					param('experiment_species', '');
	
					if($err_str eq "")
					{
						#Load experiment processing message with a DIV for loading in the results from creating the experiment -
						# this is where the error messages or the Success message will be displayed...
						if($DEVELOPER_VERSION) { print DEVEL_OUT "Experiment at '$experiment_dir' is processing...\n"; }
						display_add_exp_wait_page("../copurification/$cur_user_id/Experiments/new_experiment_log_$id.txt");
					}
					else
					{ #delete the experiment directory
						if($new_experiment) { $new_experiment -> delete(); } #change to this method in user creation!
						
						my $ret_err = "";
						if($experiment_dir) { $ret_err = delete_directory($experiment_dir); }
						if($ret_err) { $err_str .= "<br>$ret_err<br>"; }
						
						if($DEVELOPER_VERSION) { print DEVEL_OUT "Error, Experiment at '$experiment_dir' deleted: $err_str\n"; }
						display_private_error_page("Your experiment could not be created due to the following errors:<br><br>" . $err_str);
					}
				}
				elsif($action eq 'ViewExperiment') #done frames
				{
					my $exp_id = param_check('Id');
					
					#check if expid is in DB, get the owner
					my $exp = Biochemists_Dream::Experiment -> retrieve($exp_id);
					if ($exp)
					{
                        my $project = $exp -> Project_Id;
						my $cur_user_id = $project -> get("User_Id");
						if (-d "$BASE_DIR/$DATA_DIR/$cur_user_id/Experiments/$exp_id" && -e "$BASE_DIR/$DATA_DIR/$cur_user_id/Experiments/$exp_id/$PROCESS_GELS_LOG_FILE_NAME")
						{
							#print out the experiment details page:
							display_frame2('EXPERIMENT', 0, $exp_id);
							
						}
						else
						{
							display_add_exp_wait_page("../copurification/$cur_user_id/Experiments/new_experiment_log_$exp_id.txt");
						}
                    }
					else
					{
						display_private_error_page("Experiment not found in database.<br>");
					}

				}
				elsif($action eq 'Make Public')
				{
					#get the gel id's to make public
					my @ids = param_check('gels_public',1);
					my $exp_id = param_check('experiment_id');
	
					foreach (@ids)
					{
						my $gel = Biochemists_Dream::Gel -> retrieve($_);
						$gel -> set('Public' => 1);
						$gel -> update();
					}
					display_frame2('EXPERIMENT', 0, $exp_id, 0);
				}
				elsif($action eq 'MyProcedures')
				{
					display_frame2('PROCEDURES');
				}
				#########################################################################################
				elsif($action eq 'View / Edit')
				{
					my $page_type = param_check('page_type');
					if($page_type eq 'procedures')
					{
						my $proc_id = param_check('procedure_id');
						#if($DEVELOPER_VERSION) { print DEVEL_OUT "proc_id in View/Edit: $proc_id\n"; }
						#print out the procedures page w/ edit
						display_frame2('PROCEDURES', 0, $proc_id, 1);
					}
				}
				elsif($action eq 'Create Procedure')
				{
					my $new_name = param_check('name');
					my $new_file_contents = param_check('file_contents');
					my $new_proc_id;
	
					my $error_str = "";
					local Biochemists_Dream::Experiment_Procedure -> db_Main -> { AutoCommit }; #turn off autocommit (in this block only)
					eval
					{
						my $new_exp_proc = Biochemists_Dream::Experiment_Procedure -> insert({Name => $new_name, User_Id => $g_user_id, });
						my $new_proc_id = $new_exp_proc -> get('Id');
	
						#open the file and save contents:
						if(open(SOP_FILE, ">$BASE_DIR/$DATA_DIR/$g_user_id/Experiment_Procedures/$new_proc_id.txt"))
						{
							print SOP_FILE $new_file_contents;
							close(SOP_FILE);
						}
						else { $error_str = "Could not create Procedure file ($new_proc_id)"; }
	
					}; #end eval block
					if($@) { $error_str = $@; }
	
					if($error_str eq "")
					{
						display_frame2('PROCEDURES_CREATED');
					}
					else
					{ #delete the newly created user from the database, and the user directory
						Biochemists_Dream::Experiment_Procedure -> dbi_rollback;
	
						display_private_error_page($error_str);
					}
				}
				#this code in elsif will add ms data to table and upload file				
				elsif($action eq 'Save MS Data' or $action eq 'Del MS Data')
				{
					my @params = param_check();
					my $band_or_lane = param_check('band_or_lane');
					my $update_or_delete = param_check('update_or_delete');
					my $Redisplay_Lane_Popup = param_check('Redisplay_Lane_Popup');
					my $cur_ms_search_engine = param_check('cur_ms_search_engine');
					my $cur_local_ms_file = param_check('cur_local_ms_file'); #may have to figure it out
					my $ms_protein_id_method = param_check('ms_protein_id_method'); 
					my $ms_search_engine_for_band  = param_check('ms_search_engine_for_band '); 
					my $mass_spect_file_for_band = param_check('mass_spect_file_for_band'); 
					my $ms_protein_name = param_check('ms_protein_name'); 
					my $incoming_band_id = param_check('Band_Id_for_Popup');
					
					my $save_err = "";
					if ($band_or_lane eq 'lane')
					{
						$save_err = add_mass_spect_data_and_file_to_lane ();
						##$Redisplay_Lane_Popup = param_check('Redisplay_Lane_Popup');
					} else
					{
						$save_err = process_mass_spect_protein_to_band ();
						print DEVEL_OUT "Save Band Error: '$err'\n";
					}
					my $Exp_Id = param_check('Exp_Id_for_Popup');
					#print out the experiment details page:
					display_frame2('EXPERIMENT', 0, $Exp_Id, 0, $save_err);
				}
				
				##########################################################################################################
				## Edit projects/experiments/users in the DB ##
				elsif($action eq 'Edit')
				{
					my $page_type = param_check('page_type');
					if($page_type eq 'project')
					{
						my $project_id = param_check('project_parent_id');
	
						#print out the project details page w/ edit
						display_frame2('PROJECT', 0, $project_id, 1);
					}
					elsif($page_type eq 'experiment')
					{
						my $exp_id = param_check('experiment_id');
	
						#print out the experiemnt details page w/ edit
						display_frame2('EXPERIMENT', 0, $exp_id, 1);
					}
					elsif($page_type eq 'user')
					{
						display_frame2('USER');
					}
	
				}
				elsif($action eq 'DeleteFile')
				{
					#delete the file but first check if it is associated with any Projects/Experiments
					#if it is then return message saying it cannot be deleted...
					
					my $sub_dir = param_check('SubDir');
					my $file_name = param_check('File');
					$file_name = lc($file_name);
					
					#load experiments for this user:
					#use SQL to get any Exp's with the associated file name for that user
					#connect to data source for getting min/max
					my ($data_source, $db_name, $user, $password) = getConfig();
					my $dbh = DBI->connect($data_source, $user, $password, { RaiseError => 1, AutoCommit => 0 });
					my @cols = undef;
					if ($sub_dir eq 'Experiment_Procedures')
					{
						@cols = $dbh -> selectrow_array("SELECT Count(Id) FROM Experiment WHERE Project_Id IN 
								(SELECT Project_Id FROM Project WHERE User_Id = $g_user_id) AND 
								Experiment_Procedure_File = '$file_name';");
						
					}
					elsif($sub_dir eq 'Gel_Details')
					{#returns $rv == 1 ***
						@cols = $dbh -> selectrow_array("SELECT Id FROM Experiment WHERE Project_Id IN 
								(SELECT Project_Id FROM Project WHERE User_Id = $g_user_id) AND 
								Gel_Details_File = '$file_name';");
					}
					
					if (@cols && $cols[0] > 0)
					{
						#file is connected to experiments, can't delete!
						display_frame2('PROCEDURES', 0, '', '', "The file '$file_name' is associated with $cols[0] Experiment(s). First remove the file by editing the Experiment(s), then delete the file.");
					}
					else
					{
						#delete file on file system
						unlink "$BASE_DIR/$DATA_DIR/$g_user_id/$sub_dir/$file_name";
						display_frame2('PROCEDURES', 0, '', '', "'$file_name' has been successfully deleted from your file list.");
					}
					
				}
				elsif($action eq 'Cancel')
				{
					my $page_type = param_check('page_type');
					if($page_type eq 'project')
					{
						my $project_id = param_check('project_parent_id');
	
						#print out the project details page
						display_frame2('PROJECT', 0, $project_id);
					}
					elsif($page_type eq 'experiment')
					{
						my $exp_id = param_check('experiment_id');
	
						#print out the experiemnt details page w/ edit
						display_frame2('EXPERIMENT', 0, $exp_id);
					}
					elsif($page_type eq 'user')
					{
						display_frame2('PROJECT', 0, -1);
					}
					# elsif($page_type eq 'procedures')
					# {
						# display_frame2('PROCEDURES');
					# }
				}
				elsif($action eq 'Save Changes')
				{
					my $page_type = param_check('page_type');
					if($page_type eq 'project')
					{
						my $project_id = param_check('project_parent_id');
						my $new_name = param_check('project_name') || '?'; #error case if no name given, must have project name...!add javascript to block this!
						my $new_description = param_check('project_description') || undef; #let description column be NULL if user enters no description
						my @new_shared_users = param_check('shared_users',1);
						
						#save the changes to the database...
						my $project = Biochemists_Dream::Project -> retrieve($project_id);
						$project -> set('Name' => $new_name, 'Description' => $new_description);
						$project -> update(); #save to db
						
						#delete shared users and add selected
						Biochemists_Dream::Shared_Projects->search(Project_Id => $project_id)->delete_all;
						foreach my $new_id (@new_shared_users)
						{
							my $sh = Biochemists_Dream::Shared_Projects->insert({ 
							Project_Id  	=> $project_id,
							User_Id 	=> $new_id});
						}
						param('project_name', '');
						param('project_description', '');
	
						#print out the project details page
						display_frame2('PROJECT', 1, $project_id);
					}
					elsif($page_type eq 'experiment')
					{
						my $exp_id = param_check('experiment_id');
						my $new_name = param_check('experiment_name') || '?'; #error case if no name given, must have project name...!add javascript to block this!
						my $new_description = param_check('experiment_description') || undef; #let description column be NULL if user enters no description
						#my $new_species = param_check('experiment_species');
						my $new_proc_file = param_check('experiment_procedure');
						if ($new_proc_file eq '(none selected)') { $new_proc_file = undef; } else { $new_proc_file = lc($new_proc_file); }
						my $new_gel_file = param_check('gel_details');
						if ($new_gel_file eq '(none selected)') { $new_gel_file = undef; } else { $new_gel_file = lc($new_gel_file); }
	
						#save the changes to the database...
						my $experiment = Biochemists_Dream::Experiment -> retrieve($exp_id);
						$experiment -> set('Name' => $new_name, 'Description' => $new_description, 'Experiment_Procedure_File' => $new_proc_file, 'Gel_Details_File' => $new_gel_file);
						$experiment -> update(); #save to db
	
						#print out the project details page
						display_frame2('EXPERIMENT', 1, $exp_id);
					}
					elsif($page_type eq 'user')
					{
						my $new_fname = param_check('first_name');
						my $new_lname = param_check('last_name');
						my $new_orcid = param_check('orcid');
						my $new_title = param_check('title');
						my $new_inst = param_check('institution');
						my $new_email = param_check('email');
						my $new_pwd = param_check('password');
						if($new_pwd eq "    ") { $new_pwd = 0; }
	
						if($new_pwd)
						{
							my $salt = join '', ('.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z')[rand 64, rand 64];
							my $crypt_pwd = crypt($new_pwd, $salt);
							$g_the_user -> set('First_Name' => $new_fname, 'Last_Name' => $new_lname, 'OrcID' => $new_orcid, 'Title' => $new_title, 'Institution' => $new_inst, 'Email' => $new_email, 'Password' => $crypt_pwd);
						}
						else { $g_the_user -> set('First_Name' => $new_fname, 'Last_Name' => $new_lname, 'OrcID' => $new_orcid, 'Title' => $new_title, 'Institution' => $new_inst, 'Email' => $new_email); }
	
						$g_the_user -> update(); #save to db
	
						display_frame2('USER UPDATED');
					}
					elsif($page_type eq 'procedures')
					{
						my $new_name = param_check('name');
						my $new_file_contents = param_check('file_contents');
						my $proc_id = param_check('procedure_id');
	
						#open the file and save contents:
						if(open(SOP_FILE, ">$BASE_DIR/$DATA_DIR/$g_user_id/Experiment_Procedures/$proc_id.txt"))
						{
							print SOP_FILE $new_file_contents;
							close(SOP_FILE);
	
							my $exp_proc = Biochemists_Dream::Experiment_Procedure -> retrieve($proc_id);
							$exp_proc -> set('Name' => $new_name);
							$exp_proc -> update(); #save to db
	
							display_frame2('PROCEDURES_UPDATED');
						}
						else
						{
							display_private_error_page("Could not update Procedure file ($proc_id)");
						}
					}
					elsif($page_type eq 'ms_lane_info')
					{
					}
				}
				else
				{#print error screen for unknown action
					display_private_error_page("Unknown action.");
				}
			}
			else
			{#user not logged in...
				display_private_error_page("User is not logged in.");
			}
		}
	}
};
if ($@)
{
	if($DEVELOPER_VERSION) { print DEVEL_OUT "Exception thrown: $@\n"; }
	if($g_frame eq '1') { display_frame1_error_page("$@"); }
	elsif($g_frame eq '2') { display_private_error_page("$@"); }
	else { display_public_error_page("$@"); }
}
*STDERR = *OLD_STDERR;
if($DEVELOPER_VERSION) { close(DEVEL_OUT); }

######################################################################################

sub make_sql_safe_str
{   
    #This function REMOVES the following characters: \x00, \n, \r, \, ', " and \x1a.
    
    my $input = shift;
    $input =~ s/'//g;
    $input =~ s/"//g;
    $input =~ s/\n//g;
    $input =~ s/\r//g;
    $input =~ s/\\//g;
    $input =~ s/\x00//g;
    $input =~ s/\x1a//g;
    
    return $input;
}

sub validate
{
    #check param name and value and returned escaped value OR if invalid return 0
    my $param=shift;
    my $value=shift;
	
	print DEVEL_OUT "param=$param, value=$value\n.";
	$value =~ s/^\s+//;
	$value =~ s/\s+$//;
    
    if ($value eq "") { return (1,''); } #allow for empty value
    
	my $valid_param=0;
	my $code;
	if(defined $ALLOWED_HTML_PARAM_NAMES{$param})
	{ 
		$valid_param = 1;
		$code = $ALLOWED_HTML_PARAM_NAMES{$param};
	}
	else
	{
		foreach my $header (keys %ALLOWED_HTML_PARAM_HEADERS) 
		{
			if($param =~ /^$header/)
			{
				$valid_param = 1;
				$code = $ALLOWED_HTML_PARAM_HEADERS{$header};
				last;
			}
		}
	}
	
    if ($valid_param)
    {
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
                open(my $f, '>>', "$BASE_DIR/$DATA_DIR/input_validation_report.txt") || die "Failed to open file in param_check, Please contact support\@copurification.org.";
                print $f "Not valid: \'$param\' \'$value\'\n\n";
                close $f;
                return (0,0);
            }
        }
        elsif($first_char eq '-' && $last_char eq '-')
        { #it's -TEXT-, -PASSWORD- or -FILENAME-
            if($code eq '-TEXT-')
            {#allow any chars for text (?)
                return (1,make_sql_safe_str($value)); # important that the safe version is used for SQL
            }
            elsif($code eq '-PASSWORD-')
            {#allow any chars for password (?)
                return (1,$value); # no changing of password, it won't be sent to SQL, it is encoded first
            }
            elsif($code eq '-FILENAME-')
            {
				#return (1,make_sql_safe_str(escape_filename($value))); # might as well check for valid file name as well
				return (1,make_sql_safe_str($value)); # escape_filename returning blank value !?
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
            open(my $f, '>>', "$BASE_DIR/$DATA_DIR/input_validation_report.txt") || die "Failed to open file in param_check, Please contact support\@copurification.org.";;
            print $f "Not valid: \'$param\' \'$value\'\n\n";
            close $f;
            return (0,0);
        }
    }
    else
    {	
		open(my $f, '>>', "$BASE_DIR/$DATA_DIR/input_validation_report.txt") || die "Failed to open file in param_check, Please contact support\@copurification.org.";
		print $f "Not valid: \'$param\' \'$value\' (unkown parameter)\n\n";
		close $f;
		return (0,0);
	}
}

sub param_check_file_name
{
	my $param_name = $_[0];
	my $val = $_[1];
	my ($is_valid,$safe_val) = validate($param_name, $val);
	if (!$is_valid)
	{
		#invalid input or value
		die "param_check_file_name() failed, Please contact support\@copurification.org.";
	}
	else
	{
		return $safe_val;
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
			if(not @values) { return @values; }
            
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
			if(not defined $val) { return $val; }
            my ($is_valid,$safe_val) = validate($param_name, $val);
            if (!$is_valid)
            {
                #invalid input or value
				die "paramcheck() failed, ($param_name, $val) Please contact support\@copurification.org.";
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

sub call_new_experiment
{
	my $id=shift;
	my $root_dir=shift;
	my $species=shift;
	my $gel_remote_fname_list=shift;
	my $gel_id_fname_list=shift;
	my $gel_ext_fname_list=shift;
	
	if($DEVELOPER_VERSION) { print DEVEL_OUT "Calling new_experiment.pl: $id, $root_dir, $species, $gel_remote_fname_list, $gel_id_fname_list, $gel_ext_fname_list\n"; }
	
	#my $proc1 = Proc::Background->new("perl", "new_experiment.pl", "$id", "$root_dir", "$species", "$gel_remote_fname_list", "$gel_id_fname_list", "$gel_ext_fname_list");
	system("perl new_experiment.pl \"$id\" \"$root_dir\" \"$species\" \"$gel_remote_fname_list\" \"$gel_id_fname_list\" \"$gel_ext_fname_list\" > /dev/null 2>&1 &");
	
	return "";

}

sub display_frameset_for_link
{
	my $sp=shift; #"Saccharomyces cerevisiae"; #"Homo sapiens";
	my $pr=shift; #"1 NUP1"; #"43 zinc finger CCCH domain-containing protein 18 isoform 2";
	my $us=shift; #"3 Zhanna Hakhverdyan"; #"63 Kinga Winczura";
	print header();
	
	# http://copurification.org/copurification-cgi/copurification.pl?submit=SearchPublicGels
	
	print <<HTMLPAGE;
		<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN"
		   "http://www.w3.org/TR/html4/frameset.dtd">
		<HTML>
		<HEAD>
		<TITLE>copurification.org</TITLE>
		</HEAD>
		<frameset cols="10%,80%,10%" border="1" framespacing="0">
		<frame src="about:blank" />
			<frameset rows="105,*,55">
			 <frame src="../copurification-cgi/copurification.pl?frame=1p" name="frame1p" noresize scrolling="no">
			 <FRAME src="../copurification-cgi/copurification.pl?action=Choose Reagents;species=$sp;protein=$pr;users=$us" name="frame2p" noresize>
		 	<frame src="../copurification-html/footer.html" name="frame3p" noresize scrolling="no">
		 	</frameset>
		<frame src="about:blank" />
		</frameset>
		</HTML>
HTMLPAGE
}

#cookie, type, mode, message
sub display_frameset
{
	my $cookies_ref = shift;
	if($cookies_ref) { print header(-cookie => $cookies_ref); }
	else { print header(); }
	
	my $type = shift;
	
	if ($type eq 'PUBLIC')
	{
		my $mode = shift;
		if (!$mode)
		{
			$mode = 'Home';
		}
		if ($mode eq 'MESSAGE')
		{
			my $msg = shift;
			$mode = $mode . ';Text=' . $msg;
		}
		
		print <<HTMLPAGE;
		<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN"
		   "http://www.w3.org/TR/html4/frameset.dtd">
		<HTML>
		<HEAD>
		<TITLE>copurification.org</TITLE>
		</HEAD>
		<frameset cols="10%,80%,10%" border="1" framespacing="0">
		<frame src="about:blank" />
			<frameset rows="105,*,55">
			 <frame src="../copurification-cgi/copurification.pl?frame=1p" name="frame1p" noresize scrolling="no">
			 <FRAME src="../copurification-cgi/copurification.pl?frame=2p;mode=$mode" name="frame2p" noresize>
		 	<frame src="../copurification-html/footer.html" name="frame3p" noresize scrolling="no">
		 	</frameset>
		<frame src="about:blank" />
		</frameset>
		</HTML>
HTMLPAGE
	}
	else
	{
		
		print <<HTMLPAGE;
		<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN"
		   "http://www.w3.org/TR/html4/frameset.dtd">
		<HTML>
		<HEAD>
		<TITLE>copurification.org</TITLE>
		</HEAD>
		<frameset cols="10%,80%,10%" border="1">
		<frame src="about:blank" />
			<frameset rows="105,*,55">
			<frame src="../copurification-cgi/copurification.pl?frame=3" name="frame3" noresize  scrolling="no">
			<FRAMESET cols="25%, 75%">
			  <FRAME src="../copurification-cgi/copurification.pl?frame=1" name="frame1" noresize>
			  <FRAME src="../copurification-cgi/copurification.pl?frame=2" name="frame2" noresize>
			</FRAMESET>
			<frame src="../copurification-html/footer.html" name="frame4" noresize scrolling="no"> 
			</frameset>
		<frame src="about:blank" />
		</frameset>
		</HTML>
HTMLPAGE
	}
	

	
}

sub display_private_query_page
{
	#first, experiments
	my @exp_ids = param_check('experiment_checkbox',1);
	my $exp_id_list = join(',', @exp_ids);

	#next, projects
	my @proj_ids = param_check('project_checkbox',1);
	my $proj_id_list = join(',', @proj_ids);
	
	#retrieving species for the selected projects/experiments 
	#also proteins below
	my $where_clause;
	if ($exp_id_list || $proj_id_list)
	{
		if (!$exp_id_list)
		{
			my @exps = Biochemists_Dream::Experiment -> retrieve_from_sql("project_id in ($proj_id_list)");
			if (!@exps)
			{
				display_private_error_page("Selected Project(s) have no associated Experiments.");
				return;
			}
			$where_clause = "(project_id in ($proj_id_list))";
		}
		elsif(!$proj_id_list)
		{
			$where_clause = "(id in ($exp_id_list))";
		}
		else
		{
			$where_clause = "(id in ($exp_id_list) or project_id in ($proj_id_list))";
		}
	}
	else { display_private_error_page("You must select at least one Project or Experiment."); return; }
	
	my @species = Biochemists_Dream::Species -> retrieve_from_sql(qq{ name in (select species from experiment where $where_clause) });
	my @species_names;
	print qq!\n<SCRIPT LANGUAGE="JavaScript">\nvar speciesAndProteins = {};\n!;
	my $default_index = 0; 
	foreach (@species)
	{
		my $name = $_ -> get('Name');
		push @species_names, $name;
		
		#load proteins for each species 
		my $array_str1 = '';
		my @proteins = Biochemists_Dream::Protein_DB_Entry -> retrieve_from_sql(
			qq{ Protein_DB_Id IN (SELECT Id FROM Protein_DB WHERE Species = '$name') AND EXISTS
			    (SELECT * FROM Lane WHERE Lane.Captured_Protein_Id = Protein_DB_Entry.Id AND EXISTS
			    (SELECT * FROM Gel WHERE Gel.Id = Lane.Gel_Id AND Gel.Experiment_Id in 
			    (select Id from Experiment where $where_clause))) });
		
		foreach my $protein (@proteins)
		{
			my $p_id = $protein -> get('Id');
			my $p_name = $protein -> get('Common_Name');
			
			#print javascript
			$array_str1 .= qq!['$p_id $p_name','$p_name'],!;
		}
		print qq!speciesAndProteins['$name'] = [$array_str1];\n!;
	}
	print <<FUNCTIONS;
	function changeSpeciesList()
	{
		var speciesList=document.getElementById("species");
		var proteinList=document.getElementById("protein");
		while (proteinList.options.length)
		{
			proteinList.remove(0);
		}
		if(speciesList.selectedIndex >= 0)
		{
			var selSpecies=speciesList.options[speciesList.selectedIndex].value;
			
			var proteins = speciesAndProteins[selSpecies];
			if (proteins)
			{
				for (var i = 0; i < proteins.length; i++)
				{
					var protein=new Option(proteins[i][1],proteins[i][0]);
					proteinList.options.add(protein);
				}
			}
		}
		changeProteinList();
	}
	function checkAndSubmit()
	{
		document.getElementById("main_form").submit();
		
	}
FUNCTIONS
	print qq!</SCRIPT>\n!;
	
	print h2('Search My Gels:'),
		  '<table>',
		  '<tr><td>',
		  "Species:&nbsp;</td><td>",
		  popup_menu(-name=>'species', -values=>\@species_names, -id=>'species', -onchange=>'changeSpeciesList();'),
		  '</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td>',
		  "Tagged Protein:&nbsp;</td><td>",
		  '<select name="protein" id="protein" onchange="changeProteinList();"></select>',
		  '</td></tr>',
		  '</table><br>';
		  
	print '<p>';
	#show projects/exps to search in above (Filter out exp ids that are already part of a project that was chosen)
	#add js so that if user checks a project all experiments in the project are checked as well (but not subprojects)
	if ($proj_id_list)
	{
		print '<u>Gels in the these Project(s) will be searched:</u> ';
		my @projects = Biochemists_Dream::Project -> retrieve_from_sql(qq{ Id IN ($proj_id_list) });
		my $first = 1;
		foreach(@projects)
		{
			my $name = $_ -> get('Name');
			my $id = $_ -> get('Id');
			if ($first) { $first = 0; } else { print ', '; }
			print "<b>$name</b>";
			print qq!<input type="hidden" name="projects_name" value="$name">!;
			print qq!<input type="hidden" name="projects_id" value="$id">!; 
		}
		print '<br><span style="font-size:0.9em;">(only gels in the designated project are searched, subprojects must be explicitly chosen to be searched)</span><br><br>';
	}
	
	
	if ($exp_id_list)
	{
		print '<u>Gels in the these Experiment(s) will be searched:</u> ';
		my @exps = Biochemists_Dream::Experiment -> retrieve_from_sql(qq{ Id IN ($exp_id_list) });
		my $first = 1;
		foreach(@exps)
		{
			my $name = $_ -> get('Name');
			my $id = $_ -> get('Id');
			my $project = $_ -> Project_Id;
			my $project_name = $project -> get('Name');
			if ($first) { $first = 0; } else { print ', '; }
			
			print "<b>$name</b> (in Project '$project_name')";
			print qq!<input type="hidden" name="exps_name" value="$name">!;
			print qq!<input type="hidden" name="exps_id" value="$id">!;
			print qq!<input type="hidden" name="exps_proj_name" value="$project_name">!; 
		}
		print '<br><br>';
	}
	print '</p>';
	print qq!\n<SCRIPT LANGUAGE="JavaScript">changeSpeciesList(); changeProteinList();</script>\n!;

	print qq!<input type="button" value="Next" onclick="checkAndSubmit();">!;
	print qq!<input type="hidden" name="action" value="Choose Reagents User">!;
	
}

sub display_private_query_page2
{
	#read in species/protein/PROJECTS/EXPERIMENTS
	my $species = param_check('species');
	my $protein = param_check('protein');
	
	my @projs_name = param_check('projects_name',1);
	print hidden('projects_name', @projs_name);
	my @projs_id = param_check('projects_id',1);
	print hidden('projects_id', @projs_id);
	
	my @exps_name = param_check('exps_name',1);
	print hidden('exps_name', @exps_name);
	my @exps_id = param_check('exps_id',1);
	print hidden('exps_id', @exps_id);
	my @exps_proj_name = param_check('exps_proj_name',1);
	print hidden('exps_proj_name', @exps_proj_name);
	
	my $protein_id;
	
	print h2('Search My Gels - Choose Reagents:');
	
	private_query_display_search_info($species, $protein, \@projs_name, \@exps_name, \@exps_proj_name, $protein_id);
	
	#print "<br>";
	display_srf_options();
	
	#load reagents for these constraints, and display
	display_reagents_for_query('PRIVATE', $protein_id, join(',', @projs_id), join(',', @exps_id));
	
	print <<FUNCTIONS;
	<script>
	function checkAndSubmit()
	{
		document.getElementById("main_form").submit();
		
	}
	</script>
FUNCTIONS
	
	#print submit('submit', 'Back');
	print qq!<input type="button" value="Set Ranges" onclick="checkAndSubmit();">!;
	print qq!<input type="hidden" name="action" value="Set Ranges User">!;
	
}

sub display_srf_options
{
	print qq!Include lanes using multiple reagents: !;
	print qq!<input type="radio" name="srf_choice" value="multiple"> Yes!;
	print qq!<input type="radio" name="srf_choice" value="nomult" checked> No<BR><BR>!;
}
sub display_reagent_ranges_for_query
{
	my $type = shift;
	my $search_type = shift;
	my $protein_id = shift;
	my $user_id_list;
	my $proj_id_list; my $exp_id_list;
	my $where_clause;
	if ($type eq 'PUBLIC')
	{
		$user_id_list = shift;
	}
	else
	{
		$proj_id_list = shift;
		$exp_id_list = shift;
		if (!$exp_id_list)
		{
			$where_clause = "(project_id in ($proj_id_list))";
		}
		elsif(!$proj_id_list)
		{
			$where_clause = "(id in ($exp_id_list))";
		}
		else
		{
			$where_clause = "(id in ($exp_id_list) or project_id in ($proj_id_list))";
		}
	}
	
	my @types = Biochemists_Dream::Reagent_Types -> retrieve_from_sql(qq{ Display_Order > 0 ORDER BY Display_Order});
	#find out if any Reagents were chosen for INCLUDE
	my $chosen = 0;
	foreach (@types)
	{
		my @reagents_chosen = param_check("list_include_$_",1);
		if(@reagents_chosen) { $chosen = 1; last; }
	}
	if ($chosen)
	{
		my $comment = $search_type eq 'and' ? '(all reagents must be present)' : '(at least one reagent must be present)';
		print "Search Type: $search_type $comment<br>";
		print hidden('search_type', $search_type);
	}
	
	#print js to check min/max range values
	print qq!\n<SCRIPT LANGUAGE="JavaScript">\n!;
	print <<FUNCTIONS2;
	function checkMin(idMin, idMax, min)
	{
		
		var curMin = document.getElementById(idMin).value;
		var curMax = document.getElementById(idMax).value;
		//alert('checkMin: '+ curMin + ' ' + curMax + ' ' + min);
		if(parseInt(curMin) > parseInt(curMax))
		{
			document.getElementById(idMin).value = curMax;
		}
		else if(parseInt(curMin) < parseInt(min))
		{
			document.getElementById(idMin).value = min;
		}
	}
	function checkMax(idMin, idMax, max)
	{
		var curMin = document.getElementById(idMin).value;
		var curMax = document.getElementById(idMax).value;
		
		if(parseInt(curMin) > parseInt(curMax))
		{
			document.getElementById(idMax).value = curMin;
		}
		else if(parseInt(curMax) > parseInt(max))
		{
			document.getElementById(idMax).value = max;
		}
	}
FUNCTIONS2
	print qq!</SCRIPT>\n!;
	
	#read in reagents, for each reagent type, get the chosen values of the corresponding list box
	#and output each chosen reagent with range information and boxes to enter range choices
	
	#connect to data source for getting min/max
	my ($data_source, $db_name, $user, $password) = getConfig();
	my $dbh = DBI->connect($data_source, $user, $password, { RaiseError => 1, AutoCommit => 0 });
	
	my $type_i = 1; my @ids = ();
	if ($chosen)
	{
		print "<br>INCLUDE Reagents - Enter amounts to search:<br>";
		print "<table cellpadding=10><tr>";
		
		foreach (@types)
		{
			my @reagents_chosen = param_check("list_include_$_",1);
			if(@reagents_chosen)
			{
				my $sth;
				if ($type eq 'PUBLIC')
				{
					$sth = $dbh -> prepare("SELECT Amount_Units, MIN(Amount), MAX(Amount) FROM Lane_Reagents WHERE Reagent_Id=? AND EXISTS
								(SELECT * FROM Lane WHERE Lane.Id = Lane_Reagents.Lane_Id AND Captured_Protein_Id = $protein_id AND EXISTS
								(SELECT * FROM Gel WHERE Gel.Id = Lane.Gel_Id AND Public=1 AND Exists
								(Select * From Experiment Where Experiment.Id = Gel.Experiment_Id AND EXISTS
								(Select * From Project Where Project.Id = Experiment.Project_Id AND User_Id IN ($user_id_list))))) GROUP BY Amount_Units");
				}
				else
				{
					$sth = $dbh -> prepare("SELECT Amount_Units, MIN(Amount), MAX(Amount) FROM Lane_Reagents WHERE Reagent_Id=? AND EXISTS
								(SELECT * FROM Lane WHERE Lane.Id = Lane_Reagents.Lane_Id AND Captured_Protein_Id = $protein_id AND EXISTS
								(SELECT * FROM Gel WHERE Gel.Id = Lane.Gel_Id AND Gel.Experiment_Id in 
								(select Id from Experiment where $where_clause))) GROUP BY Amount_Units");
				}
				
				if($type_i % 3 == 0) { print "</tr><tr>"; }
				$type_i++;
				print "<td>$_(s): <br>";
				print "<table>";
				foreach (@reagents_chosen)
				{
					#get min/max
					my $name = $_;
					$name =~ s/^([0-9]+) //;
					my $id = $1;
					$sth -> execute( $id );
					push @ids, $id;
					
					my @row;
					while(@row = $sth -> fetchrow_array)
					{
						#display reagent and the min/max values for each units
						my $min_name = "reagent_min_$id" . "_$row[0]";
						my $max_name = "reagent_max_$id" . "_$row[0]";
						my $min = $row[1];  my $max = $row[2];
						$min =~ s/0+$//; $min =~ s/\.$//;
						$max =~ s/0+$//; $max =~ s/\.$//;
						print "<tr>";
						print qq!<td nowrap id="td_$min_name">$name ($row[0]):&nbsp;&nbsp;</td><td nowrap>!; 
						print qq!<input type="text" name="$min_name" id="$min_name" size="5" maxlength="10" value="$min" onkeydown="validateNumber(event);" onblur="checkMin('$min_name','$max_name',$min);" />!;
						print " - ";
						print qq!<input type="text" name="$max_name" id="$max_name" size="5" maxlength="10" value="$max" onkeydown="validateNumber(event);" onblur="checkMax('$min_name', '$max_name', $max);" />!;
						print "</tr>";
						
					}
					
				}
				print "</table>";
				print "</td>";
				
			}
		}
		print "</tr></table>";
	}
	else
	{
		print "<br>ALL Reagents allowed (unless specified in EXCLUDE list)<br>";
	}
	print hidden('reagents_include', join ',', @ids);
	
	#print out exclude reagents (don't need amount specification)
	print p("EXCLUDE Reagents:");
	print "<table >";
	@ids = (); my $num_exclude = 0;
	foreach (@types)
	{
		my @reagents_chosen = param_check("list_exclude_$_",1);
		if(@reagents_chosen)
		{
			print "<tr><td>$_(s): ";
			my $name_list = "";
			foreach (@reagents_chosen)
			{
				my $name = $_;
				$name =~ s/^([0-9]+) //;
				my $id = $1;
				push @ids, $id;
				$name_list .= $name . ", ";
			}
			$name_list =~ s/, $//;
			print "$name_list</td></tr>";
			
			$num_exclude++;
			
		}
	}
	print "</table>";
	if($num_exclude == 0) { print '(none)'; }
	print hidden('reagents_exclude', join ',', @ids);
	
	my $sth;
	if ($type eq 'PUBLIC')
	{
		$sth = $dbh -> prepare("SELECT MIN(Ph), MAX(Ph) FROM Lane WHERE Captured_Protein_Id = $protein_id AND EXISTS
				 (SELECT * FROM Gel WHERE Gel.Id = Lane.Gel_Id AND Public=1 AND Exists
				 (Select * From Experiment Where Experiment.Id = Gel.Experiment_Id AND EXISTS
				 (Select * From Project Where Project.Id = Experiment.Project_Id AND User_Id IN ($user_id_list))))");
	}
	else
	{
		$sth = $dbh -> prepare("SELECT MIN(Ph), MAX(Ph) FROM Lane WHERE Captured_Protein_Id = $protein_id AND EXISTS
				 (SELECT * FROM Gel WHERE Gel.Id = Lane.Gel_Id AND Gel.Experiment_Id IN
				 (select Id from Experiment where $where_clause))");
	}
	
	$sth -> execute();
	my @row = $sth -> fetchrow_array;
	my $min_ph = $row[0]; my $max_ph = $row[1];
	$min_ph =~ s/0+$//; $min_ph =~ s/\.$//;
	$max_ph =~ s/0+$//; $max_ph =~ s/\.$//;
	
	#output boxes to enter ph choices
	print "<br><br>";
	print p("pH of solution: ");
	print qq!<input type="text" name="ph_min" id="ph_min" size="3" maxlength="5" value="$min_ph" onkeydown="validateNumber(event);" onblur="checkMin('ph_min','ph_max',$min_ph);" />!;
	print " - ";
	print qq!<input type="text" name="ph_max" id="ph_max" size="3" maxlength="5" value="$max_ph" onkeydown="validateNumber(event);" onblur="checkMax('ph_min','ph_max',$max_ph);" />!;
	
	$dbh->disconnect();
	
}

sub display_private_query_page3
{
	#read in species/protein/PROJECTS/EXPERIMENTS
	my $species = param_check('species');
	my $protein = param_check('protein');
	
	my @projs_name = param_check('projects_name',1);
	print hidden('projects_name', @projs_name);
	my @projs_id = param_check('projects_id',1);
	print hidden('projects_id', @projs_id);
	
	my @exps_name = param_check('exps_name',1);
	print hidden('exps_name', @exps_name);
	my @exps_id = param_check('exps_id',1);
	print hidden('exps_id', @exps_id);
	my @exps_proj_name = param_check('exps_proj_name',1);
	print hidden('exps_proj_name', @exps_proj_name);
	
	#read in srf chosen value, save as hidden field 
	my $srf_choice = param_check('srf_choice');
	print hidden('srf_choice', $srf_choice);
	
	my $search_type = param_check('search_type');

	my $protein_id;
	
	print h2('Search My Gels - Set Ranges:');
	
	private_query_display_search_info($species, $protein, \@projs_name, \@exps_name, \@exps_proj_name, $protein_id);
		
	#print Single Reagent Flag choice
	    $srf_choice = param_check('srf_choice');
	if ($srf_choice eq 'multiple') {
		print '<br>Lanes with either a single reagent or multiple reagents will be displayed.<br><br>';
	} else {
		print '<br>Lanes with only a single reagent will be displayed.<br><br>';
	}

	display_reagent_ranges_for_query('PRIVATE', $search_type, $protein_id, join(',', @projs_id), join(',', @exps_id));
	
	print <<FUNCTIONS;
	<script>
	function checkAndSubmit()
	{
		document.getElementById("main_form").submit();
		
	}
	</script>
FUNCTIONS

	print "<br><br>";
	
	print qq!<input type="reset" name="reset" value="Reset" />!;
	print qq!<input type="button" value="Search" onclick="checkAndSubmit();">!;
	print qq!<input type="hidden" name="action" value="Search User">!;
	
}
sub display_public_query_page
{
	my @species = Biochemists_Dream::Species -> retrieve_all;
	my @species_names;
	print qq!\n<SCRIPT LANGUAGE="JavaScript">\nvar speciesAndProteins = {};\nvar proteinsAndUsers = {};\n!;
	my $default_index = 0; my $default_species = 'Saccharomyces cerevisiae';
	foreach (@species)
	{
		my $name = $_ -> get('Name');
		push @species_names, $name;
		if($name eq $default_species) { $default_index = $#species_names; }
		
		#load proteins for each species and and users for each protein
		my $array_str1 = '';
		my @proteins = Biochemists_Dream::Protein_DB_Entry -> retrieve_from_sql(
			qq{ Protein_DB_Id IN (SELECT Id FROM Protein_DB WHERE Species = '$name') AND EXISTS
			    (SELECT * FROM Lane WHERE Lane.Captured_Protein_Id = Protein_DB_Entry.Id AND EXISTS
			    (SELECT * FROM Gel WHERE Gel.Id = Lane.Gel_Id AND Public = 1))});
		foreach my $protein (@proteins)
		{
			my $p_id = $protein -> get('Id');
			my $p_name = $protein -> get('Common_Name');
			
			#print javascript
			$array_str1 .= qq!['$p_id $p_name','$p_name'],!;
			
			#load users for this protein
			my @users = Biochemists_Dream::User -> retrieve_from_sql(
				qq{ Id IN (SELECT User_Id FROM Project WHERE Id IN
					  (SELECT Project_Id FROM Experiment WHERE Id IN
					  (SELECT Experiment_Id FROM Gel WHERE Id IN
					  (SELECT Gel_Id FROM Lane WHERE Captured_Protein_Id = $p_id AND Public = 1))))});
			my $array_str2 = '';
			foreach my $user (@users)
			{
				my $u_id = $user -> get('Id');
				my $u_lname = $user -> get('Last_Name');
				my $u_fname = $user -> get('First_Name');
				$array_str2 .= qq!['$u_id $u_fname $u_lname','$u_lname, $u_fname'],!;
			}
			print qq!proteinsAndUsers['$p_name'] = [$array_str2];\n!;
		}
		print qq!speciesAndProteins['$name'] = [$array_str1];\n!;
	}
	
	print <<FUNCTIONS;
	function changeSpeciesList()
	{
		var speciesList=document.getElementById("species");
		var proteinList=document.getElementById("protein");
		while (proteinList.options.length)
		{
			proteinList.remove(0);
		}
		if(speciesList.selectedIndex >= 0)
		{
			var selSpecies=speciesList.options[speciesList.selectedIndex].value;
			
			var proteins = speciesAndProteins[selSpecies];
			if (proteins)
			{
				for (var i = 0; i < proteins.length; i++)
				{
					var protein=new Option(proteins[i][1],proteins[i][0]);
					proteinList.options.add(protein);
				}
			}
		}
		changeProteinList();
	}
	function changeProteinList()
	{
		var proteinList=document.getElementById("protein");
		var userList=document.getElementById("users");
		while (userList.options.length)
		{
			userList.remove(0);
		}
		if(proteinList.selectedIndex >= 0)
		{
			var selProtein=proteinList.options[proteinList.selectedIndex].text;
		
			var users = proteinsAndUsers[selProtein];
			if (users && users.length > 0)
			{
				for (var i = 0; i < users.length; i++)
				{
					var user=new Option(users[i][1],users[i][0]);
					userList.options.add(user);
				}
				userList.selectedIndex = 0;
			}
		}
	}
	function checkUserAndSubmit()
	{
		var userList=document.getElementById("users");
		if(userList.selectedIndex >= 0)
		{
			document.getElementById("frm1").submit();
		}
		else
		{
			alert("You must make a selection in the 'Submitted By' text box.");
		}
		
	}
FUNCTIONS

	print qq!</SCRIPT>\n!;
	
	print h2('Search Public Gels:'),
		  '<table>',
		  '<tr><td>',
		  "Species:&nbsp;</td><td>",
		  popup_menu(-name=>'species', -values=>\@species_names, -default=>$default_species, -id=>'species', -onchange=>'changeSpeciesList();'),
		  '</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td>',
		  "Tagged Protein:&nbsp;</td><td>",
		  '<select name="protein" id="protein" onchange="changeProteinList();"></select>',
		  '</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td>',
		  "Submitted by:&nbsp;</td><td>",
		  '<select name="users" id="users" size="5" multiple="multiple" ></select>',
		  '</td></tr>',
		  '</table>';
		  
	print qq!\n<SCRIPT LANGUAGE="JavaScript">changeSpeciesList(); changeProteinList();</script>\n!;

	print qq!<input type="button" value="Next" onclick="checkUserAndSubmit();">!;
	print qq!<input type="hidden" name="action" value="Choose Reagents">!; 
}

sub display_public_query_page2
{
	#read in species/protein/user(s)
	my $species = param_check('species');
	my $protein = param_check('protein');
	my @users = param_check('users',1);
	
	my $protein_id; my $user_ids;
	
	print h2('Search Public Gels - Choose Reagents:');
	
	public_query_display_search_info($species, $protein, \@users, $protein_id, $user_ids);
	
	#load reagents for these constraints, and display
	display_reagents_for_query('PUBLIC', $protein_id, $user_ids);
	
	#print submit('submit', 'Back');
	print submit('submit', 'Set Ranges');
	
}

sub display_public_query_page3
{
	#read in species/protein/user(s)
	my $species = param_check('species');
	my $protein = param_check('protein');
	my @users = param_check('users',1);
	my @users_ids = param_check('user_ids',1);
	my $search_type = param_check('search_type');
		
	#turn user ids into comma separated lists for sql statment
	my $user_id_list = "";
	foreach (@users_ids) { $user_id_list .= "$_, "; } 
	$user_id_list =~ s/, $//;
	
	my $protein_id; my $user_ids;
	
	print h2('Search Public Gels - Set Ranges:');
	
	public_query_display_search_info($species, $protein, \@users, $protein_id, $user_ids);
	
	display_reagent_ranges_for_query('PUBLIC', $search_type, $protein_id, $user_id_list);
	
	print "<br><br>";
	print qq!<input type="reset" name="reset" value="Reset" />!;
	print qq!<input type="submit" name="submit" value="Search"/>!;
}

#($species, $protein, \@projs_name, \@exps_name, \@exps_proj_name, $protein_id, "");
sub private_query_display_search_info
{
	my $species = $_[0];
	my $protein = $_[1];
	my @projects_name = @{$_[2]};
	my @exps_name = @{$_[3]};
	my @exps_proj_name = @{$_[4]};
	my $search_type = $_[6];
	
	#print out species, protein, user (just for fyi)
	print p("Species: $species");
	
	my $protein_name = $protein;
	$protein_name =~ s/^([0-9]+) //;
	$_[5] = $1;
	print p("Protein: $protein_name");
	
	print hidden('protein', $protein);
	print hidden('species', $species);
	
	if (@projects_name)
	{
		print '<u>Gels in the these Project(s) will be searched:</u> ';
		my $first = 1;
		foreach(@projects_name)
		{
			if ($first) { $first = 0; } else { print ', '; }
			print "<b>$_</b>";
		}
		print '<br><span style="font-size:0.9em;">(only gels in the designated project are searched, subprojects must be explicitly chosen to be searched)</span><br><br>';
	}
	
	if (@exps_name)
	{
		print '<u>Gels in the these Experiment(s) will be searched:</u> ';
		my $i = 0;
		foreach(@exps_name)
		{
			if ($i > 0) { print ', '; }
			print "<b>$_</b> (in Project '$exps_proj_name[$i]')";
			$i++;
		}
		print '<br><br>';
	}
	
	print '<BR>';
	
	return 1;
}

sub public_query_display_search_info
{#read and display species, protein, user
	my $species = $_[0];
	my $protein = $_[1];
	my @users = @{$_[2]};
	my $search_type = $_[5];
	
	#print out species, protein, user (just for fyi)
	print p("Species: $species");
	
	my $protein_name = $protein;
	$protein_name =~ s/^([0-9]+) //;
	$_[3] = $1;
	print p("Protein: $protein_name");
	
	print hidden('protein', $protein);
	print hidden('species', $species);
	
	my $user_string = ""; my @user_ids;
	foreach(@users)
	{	
		$_ =~ s/^([0-9]+) //;
		push @user_ids, $1;
		$user_string .= "$_, ";
	}
	$user_string =~ s/, $//;
	print p("Submitted by: $user_string");
	print hidden('user_ids', @user_ids);
	print hidden('users', @users);

	$_[4] = join(',', @user_ids);
	
	return 1;
}

sub display_reagents_for_query
{#display reagents for given protein, users
 #display once for include and once for exclude
	
	my $type = shift;
	my $protein_id = shift;
	my $user_list; my $proj_id_list; my $exp_id_list; my $where_clause;
	if ($type eq 'PUBLIC') { $user_list = shift; }
	else
	{
		$proj_id_list = shift;
		$exp_id_list = shift;
		
		if (!$exp_id_list)
		{
			$where_clause = "(project_id in ($proj_id_list))";
		}
		elsif(!$proj_id_list)
		{
			$where_clause = "(id in ($exp_id_list))";
		}
		else
		{
			$where_clause = "(id in ($exp_id_list) or project_id in ($proj_id_list))";
		}
	}
	
	print "<n2><u>Reagents</u></h2>";
	print "<table cellspacing=10>";
	my @options = ('include', 'exclude');
	my @html_str;
	push @html_str, ""; push @html_str, "";
	my $i = 0;
	foreach my $opt (@options)
	{
		$html_str[$i] .= '<tr><td>';
		$html_str[$i] .=  uc $opt . ':';
		if($opt eq 'include')
		{
			$html_str[$i] .=  '&nbsp;&nbsp;&nbsp;';
			$html_str[$i] .= qq!<input type="radio" name="search_type" value="and" checked="checked">and !;
			$html_str[$i] .= qq!<input type="radio" name="search_type" value="or">or !;
		}
		$html_str[$i] .=  "<table cellspacing=10><tr>";
	
		#get list of regeant types:
		my @reagent_types = Biochemists_Dream::Reagent_Types -> retrieve_from_sql(qq{ Display_Order > 0 ORDER BY Display_Order});
		foreach(@reagent_types)
		{
			my $type_name = $_ -> get('Name');
			my @reagents;
			if ($type eq 'PUBLIC')
			{
				@reagents = Biochemists_Dream::Reagent -> retrieve_from_sql(
				qq{ Reagent_Type = '$type_name' AND EXISTS (Select * From Lane_Reagents Where Reagent.Id = Lane_Reagents.Reagent_Id AND EXISTS
				   (Select * From Lane Where Captured_Protein_Id = $protein_id AND Lane.Id = Lane_Reagents.Lane_Id AND EXISTS
				   (Select * From Gel Where Gel.Id = Lane.Gel_Id AND Public = 1 AND Exists
				   (Select * From Experiment Where Experiment.Id = Gel.Experiment_id AND EXISTS
				   (Select * From Project Where Project.Id = Experiment.Project_Id AND User_Id IN ($user_list)))))) ORDER BY 'Name' } );
			}
			else
			{
				@reagents = Biochemists_Dream::Reagent -> retrieve_from_sql(
				qq{ Reagent_Type = '$type_name' AND EXISTS (Select * From Lane_Reagents Where Reagent.Id = Lane_Reagents.Reagent_Id AND EXISTS
				   (Select * From Lane Where Captured_Protein_Id = $protein_id AND Lane.Id = Lane_Reagents.Lane_Id AND EXISTS
				   (Select * From Gel Where Gel.Id = Lane.Gel_Id AND Gel.Experiment_Id in 
				   (select Id from Experiment where $where_clause)))) ORDER BY 'Name' } );
				
			}
			
			if ($#reagents > -1)
			{
				$html_str[$i] .=   "<td>";
				$html_str[$i] .=   "$type_name<br>";
				my $name = "list_$opt" . "_$type_name";
				$html_str[$i] .=  qq!<select name='$name' size=10 multiple=True>!;

				foreach(@reagents)
				{
					my $cur_reag_id = $_ -> get('Id');
					my $cur_reag_name = $_ -> get('Name');
					$cur_reag_id .= " $cur_reag_name";
					$html_str[$i] .=   qq!<option value="$cur_reag_id">$cur_reag_name</option>!;
				}
				$html_str[$i] .=  "</select>";
				$html_str[$i] .=   "</td>";
			}
		}
		$html_str[$i] .=  "</tr></table></td></tr>";
		$i++;
	}
	print $html_str[0];
	print $html_str[1];
	print "</table>";
	
}

sub display_frame1p
{
	display_title_header('PUBLIC1', "", "");
#converted FAQ page to HTML page like "HOWTO"
#this is the line taken out
#a({href=>"../copurification-cgi/copurification.pl?frame=2;submit=FAQ", target=>'frame2'}, "FAQ"),
#BAromando 08042016
	
	print a({href=>"../copurification-cgi/copurification.pl?submit=Home", target=>'frame2p'}, "Home"),
		  "&nbsp;|&nbsp;",
		  a({href=>"../copurification-cgi/copurification.pl?submit=SearchPublicGels", target=>'frame2p'}, "Search Public Gels"),
		  "&nbsp;|&nbsp;",
		  a({href=>"../copurification-cgi/copurification.pl?submit=LoginPage", target=>'frame2p'}, "Login"),
		  "&nbsp;|&nbsp;",
		  a({href=>"../copurification-cgi/copurification.pl?submit=CreateAccount", target=>'frame2p'}, "Create Account"),
		  "&nbsp;|&nbsp;",
		  a({href=>"../copurification-html/HowTo.html", target=>'frame2p'}, "HOWTO"),
		  "&nbsp;|&nbsp;",
		  a({href=>"../copurification-html/FAQ.html", target=>'frame2'}, "FAQ"),
		  "&nbsp;|&nbsp;",
		  a({href=>"../copurification-html/About.html", target=>'frame2p'}, "About"),
		  "&nbsp;|&nbsp;",
		  a({href=>"../copurification-cgi/copurification.pl?submit=Contact", target=>'frame2p'}, "Contact");
		
	print end_html();
	
}

sub display_frame2p
{
	my $mode = shift;

	display_title_header('PUBLIC2', "", "");

	if($mode eq 'LOGIN')
	{
		print qq!<form method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" id="frm1" target="_top">!;
		display_login();
	}
	elsif($mode eq 'CREATE USER')
	{
		print qq!<form method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" id="frm1">!;
		display_create_user();
	}
	elsif($mode eq 'USER CREATED')
	{
		print p("Success!  Your user account was created!");

	}
	elsif($mode eq 'SEARCH' || $mode eq 'SEARCH 2' || $mode eq 'SEARCH 3')
	{
		
		if($mode eq 'SEARCH') { print qq!<form method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" id="frm1">!; display_public_query_page(); }
		elsif($mode eq 'SEARCH 2') { print qq!<form method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" id="frm1">!; display_public_query_page2(); }
		elsif($mode eq 'SEARCH 3') { print qq!<form method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" id="frm1" target="_blank">!; display_public_query_page3(); }
		
	}
	elsif($mode eq 'PUBLICVIEW SEARCH')
	{
		#print hr();
		print qq!<form method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" id="frm1">!;
		display_public_query_page();
	}
	elsif($mode eq 'PUBLICVIEW SEARCH 2')
	{
		#print hr();
		print qq!<form method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" id="frm1">!;
		display_public_query_page2();
	}
	elsif($mode eq 'PUBLICVIEW SEARCH 3')
	{
		#print hr();
		print qq!<form method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" id="frm1" target="_blank">!;
		display_public_query_page3();
	}
	elsif($mode eq 'FAQ')
	{
		display_faq();
	}
	elsif($mode eq 'HowTo')
	{
		display_howto();
	}
	elsif($mode eq 'About')
	{
		display_about();
	}
	elsif($mode eq 'Contact')
	{
		display_contact();
	}
	elsif($mode eq 'Home')
	{
		print qq!<form method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" id="frm1" target="_top">!;
		display_home();
	}
	elsif($mode eq 'MESSAGE')
	{
		my $msg = shift;
		print p($msg);
	}
	display_footer();
}

sub display_frame1
{#for the left side frame
	#displays the project tree and add/query/compare buttons
	display_title_header('FRAME1');

	display_project_tree();

	display_footer();
}

sub display_frame3
{#for the left side frame
	#displays the project tree and add/query/compare buttons
	display_title_header('FRAME3');

	display_footer();
}

sub display_frame2
{
	my $mode = shift;
	my $reload_frame1 = shift;
	my $id = shift;
	my $edit = shift;
	my $err_msg = shift;

	if($reload_frame1)
	{
		my $javascript = qq!parent.frame1.location.reload("../copurification-cgi/copurification.pl?frame=1");!;
		display_title_header('FRAME2', $javascript);
	}
	else { display_title_header('FRAME2'); }

	if($mode eq 'PROJECT')
	{
		print qq!<form id="main_form" name="main_form" method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" target="frame2">!;
		if($id == -1) { display_add_project(''); }
		else{ display_project_page($id, $edit); }
	}
	elsif($mode eq 'EXPERIMENT')
	{
		print qq!<form id="main_form" name="main_form" method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" target="frame2">!;
		display_experiment_page($id, $edit, $err_msg);
	}
	elsif($mode eq 'QUERY')
	{
		print qq!<form method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" id="main_form">!;
		display_private_query_page();
	}
	elsif($mode eq 'QUERY2')
	{
		print qq!<form method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" id="main_form">!;
		display_private_query_page2();
	}
	elsif($mode eq 'QUERY3')
	{
		print qq!<form method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" id="main_form" target="_blank">!;
		display_private_query_page3();
	}
	elsif($mode eq 'USER')
	{
		print qq!<form id="main_form" name="main_form" method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" target="frame2">!;
		#print DEVEL_OUT "Calling display_edit_user() in display_frame2\n";
		display_edit_user();
	}
	elsif($mode eq 'USER UPDATED')
	{
		print p("Your account was successfully updated.");
	}
	elsif($mode eq 'PROCEDURES')
	{
		print qq!<form id="main_form" name="main_form" method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" target="frame2">!;
		my $msg = shift;
		display_experiment_files($msg);
	}
	elsif($mode eq 'FAQ')
	{
		display_faq();
	}
	elsif($mode eq 'HowTo')
	{
		display_howto();
	}
	elsif($mode eq 'About')
	{
		display_about();
	}
	elsif($mode eq 'Contact')
	{
		display_contact();
	}
	elsif($mode eq 'Home')
	{
		display_home();
	}
	elsif($mode eq 'MESSAGE')
	{
		;
	}

	display_footer();

}

sub display_faq
{
	print h2("Frequently Asked Questions"),
		p("Coming soon...");
	      #p("Q: What is the format for the data file when creating an Experiment (submitting gels)?"),
	      #p("A: Here is a blank", 
	      #a({href=>"../copurification-html/data_file_template.xlsx", target=>'_blank'}, "template"), 
	      #" and ",
	      #a({href=>"../copurification-html/data_file_example.xlsx", target=>'_blank'}, "example"), 
	      #" for the data file, in Microsoft Excel format (remember to 'Save As' a 'Text (tab-delimited)' file before submitting).",
	      #br(),
	      #"&nbsp;&nbsp;&nbsp;&nbsp;Alternatively, here is a ",
	      #a({href=>"../copurification-html/data_file_template.txt", target=>'_blank'}, "template"), 
	      #" and ",
	      #a({href=>"../copurification-html/data_file_example.txt", target=>'_blank'}, "example"), 
	      #" for the data file, in plain text format (tab delimited fields).",
	      #br(),
	      #"&nbsp;&nbsp;&nbsp;&nbsp;Here is a listing of the allowed fields and values with detailed explanations for some of the fields: ",
	      #a({href=>"../copurification-html/data_file_instructions.htm", target=>'_blank'}, "Data File Instructions"));
}

sub display_contact
{
	print h2("Contact Us"),
		qq!Please email !,
		qq!<script language="JavaScript">var username = "support"; var hostname = "copurification"; var linktext = username + "@" + hostname + ".org";!,
		qq!document.write("<a href='" + "mail" + "to:" + username + "@" + hostname + ".org" + "'>" + linktext + "</a>");</script>!,
		qq! with questions/comments about this site.!;
		
		#qq!<input type="hidden" name="action" value="contact_us">!,
		#qq!Name: <input type="text" name="name" size="30" maxlength="30"><br><br>!,
		#qq!Email: <input type="text" name="email" size="30" maxlength="30"><br><br>!,
		#qq!Subject: <input type="radio" name="subject" value="bug" checked>report a bug&nbsp;&nbsp;&nbsp;!,
		#qq!<input type="radio" name="body" value="new_feature">request a new feature&nbsp;&nbsp;&nbsp;!,
		#qq!<input type="radio" name="body" value="help">request help/support&nbsp;&nbsp;&nbsp;!,
		#qq!<input type="radio" name="body" value="collaborate">collaborate with us&nbsp;&nbsp;&nbsp;!,
		#qq!<input type="radio" name="body" value="other" >other<br><br>!,
		#qq!Please type your message here:<br>!,
		#qq!<textarea rows="10" cols="75" name="body"></textarea> <br><br>!,
		#qq!<input type="submit" value="Submit">!;
	
}

sub display_home
{
	print <<START_HTML;
		<h2>Welcome to copurification.org!</h2>
		<p>We curate images displaying protein co-purification banding patterns resulting from affinity capture followed
		by e.g. SDS-PAGE and protein staining. We store the conditions of the experiment and link to the resulting banding
		patterns so purifications under different conditions can be compared to one another. 
		We currently curate Saccharomyces cerevisiae, Escherichia coli, Mus Musculus and Homo sapiens genes and proteins. For more information on the
		specification format for these species, please see our <a href="../copurification-html/HowTo.html#ProteinName" target="frame2p">HOWTO</a> page.
		<p><p>You may view gels currently in our <a href="../copurification-cgi/copurification.pl?submit=SearchPublicGels" target="frame2p">public database</a>,
		which has been seeded with data resulting from our recently developed
		affinity capture conditions screening process (<a href="http://www.nature.com/nmeth/journal/vaop/ncurrent/full/nmeth.3395.html" target="blank">Hakhverdyan et al</a>),
		and also <a href="../copurification-cgi/copurification.pl?submit=CreateAccount" target='frame2p'>create an account</a>
		if you'd like to upload
		and manage your own gels.  Your data are kept private until you choose to release them to the public (e.g. after publication).
		For more details, please see the <a href="../copurification-html/About.html" target="frame2p">About</a> page.<p>
		<p>This is public beta version 0.9 of this site and it will continually evolve to meet the needs of curating and data
		mining affinity capture co-purification experiments - as well as incorporating the latest appropriate "minimum information" standards.
		We welcome
		<a href="../copurification-cgi/copurification.pl?submit=Contact" target="frame2p">feedback and collaboration</a>
		from the community.</p>
<!--  New Stuff  -->
		<p><img src="../copurification-html/new.jpg" height="20" width="27">&nbsp;&nbsp;Latest Updates...<br>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; * We have added support for the curation of Mouse genes via MGI systematic naming.
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; * A new feature has been added so that users can share Projects and Experiments with other users of the system.  
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; * The ability to assign a protein or possible proteins to gel data has now been added.  At the lane level,
an XML file from a MS Search Engine may be assigned and used for further analysis.  Currently, 5 search
engines are accepted: XTandem, SEQUEST, Mascot, MSGFPlus, Andromeda.  In addition, proteins may be assigned at the band level.
This may be done by assigning a protein name to the band based on one of three Protein ID Methods (Western Blot, Mass
Spectrometry, or Other).  When choosing MS, a file must be assigned as well just as in the lane assignment.

<!--  New Stuff  -->

		<p>Interested in keeping abreast of our work on affinity capture optimization and data curation?  &nbsp;Please enter your contact email
		address here and we'll update you with the latest developments...</p>
		  
		Email Address <input type="text" name="email" size="30" maxlength="30">&nbsp;&nbsp;&nbsp;
		<input type="hidden" name="action" value="ContactList">
		<input type="submit" value="Submit">
		  
		<br><br><br>
		<p>This site was created by Sarah Keegan, Zhanna Hakhverdyan, John LaCava and David Fenyo - and is supported and maintained
		by The <a href="http://www.ncdir.org" target="_blank">NCDIR</a> and <a href="http://www.fenyolab.org" target="_blank">The Fenyo Lab</a>.
		<script language="JavaScript">
	var username = "support"; var hostname = "copurification"; var linktext = "Contact Us";
	document.write("<a href='" + "mail" + "to:" + username + "@" + hostname + ".org" + "'>" + linktext + "</a>");
	</script>.</p>

START_HTML
}

sub display_experiment_files()
{#load miape-AC and miape-GE files for this user - display them and also form for deletion and upload of new files
	
	my $msg = shift;
	#print hr();
	
	#MIAPE-AC files
	print h3("Experimental Procedures (MIAPE-AC)");
	display_files_form("Experiment_Procedures");
	
	print "<br/><hr/><br/>";
	
	#MIAPE-GE files
	print h3("Gel Details (MIAPE-GE)");
	display_files_form("Gel_Details");
	
	if ($msg)
	{
		print "<br/><hr/><br/>$msg";
	}
	
}

sub display_files_form()
{
	my $sub_dir = shift;
	
	#get all txt files in the directory, display form with these files listed
	#my @file_names = <"$BASE_DIR/$DATA_DIR/$g_user_id/$sub_dir/*.txt">;
	my @file_names = get_files("$BASE_DIR/$DATA_DIR/$g_user_id/$sub_dir", ''); #add all file types for ExpProc and GelDetails!!!
	foreach my $cur_file (@file_names)
	{
		#$cur_file =~ s/^.+[\\\/]([^\\\/]+\.txt$)/$1/;
		print qq!<input type='hidden' name='$sub_dir-list' value='$cur_file'>!;
		print qq!<a href="/copurification/$g_user_id/$sub_dir/$cur_file" target="_blank">$cur_file</a>&nbsp;<a href="/copurification-cgi/copurification.pl?submit=DeleteFile;SubDir=$sub_dir;File=$cur_file"><img src='/copurification-html/close.png'></img></a><br/>!;
	}
	if (!@file_names)
	{
		print qq!(no files have been uploaded)!
	}
	print qq!<br/><br/>!;
	print qq!<input type="hidden" name="action" value="Upload">!; 
	print qq!New File: <input id='$sub_dir' name='$sub_dir' type='file'/> &nbsp;<input type='button' value='Upload' onclick='checkFileReplace("$sub_dir");'/><br/>!;
	#print qq!</form>!;
}

sub display_experiment_procedures() #NO LONGER USED: display_experiment_files() used instead!
{
	my $edit_id = shift;
	my $edit_new = shift;
	my $msg = shift;

	#load all existing procedures for the user, w/ radio buttons to edit/delete
	my @exp_procs = Biochemists_Dream::Experiment_Procedure -> search(User_Id => $g_user_id);
	my $num_exp_procs = $#exp_procs+1;

	my @exp_procs_ids; my %labels;
	foreach (@exp_procs)
	{
		my $name = $_ -> get('Name');
		my $id = $_ -> get('Id');
		push @exp_procs_ids, $id;
		$labels{$id} = $name;
	}

	if((!$edit_new) && $#exp_procs_ids >= 0) { $edit_id = $exp_procs_ids[0]; } #if this is the initial load, show the first exp proc below (its the default selected)
	my $default_id = $edit_id;

	print h3("Manage Files");

	if($#exp_procs_ids >= 0)
	{
		print radio_group(-name=>'procedure_id', -values=>\@exp_procs_ids, -default=>$default_id, -labels=>\%labels, -rows=>$num_exp_procs, -columns=>1),
			  br(),
			  submit('submit', 'View / Edit'), '&nbsp;', button('submit', 'Disable'), '&nbsp;', submit('submit', 'New'),
			  hidden('page_type', 'procedures'),
			  hr();
	}
	else
	{
		print submit('submit', 'New'),
			  hidden('page_type', 'procedures'),
			  hr();
	}

	if($msg)
	{
		print p($msg);
	}
	elsif($edit_id)
	{#we are editing an existing SOP
		my $exp_proc = Biochemists_Dream::Experiment_Procedure -> retrieve($edit_id);
		my $name_edit = $exp_proc -> get('Name');
		param('name', $name_edit);

		#read the contents of the file:
		if(open(SOP_FILE, "$BASE_DIR/$DATA_DIR/$g_user_id/Experiment_Procedures/$edit_id.txt"))
		{
			my $file = "";
			while(<SOP_FILE>) { $file .= $_; }
			param('file_contents', $file);

			print '<table><tr><td>Name&nbsp;</td>',
				  '<td>', textfield('name', $name_edit, 30, 30), '</td></tr>',
				  '<tr><td>Procedures&nbsp;</td>',
				  '<td>', textarea('file_contents',$file,10,50), '</td></tr>',
				  '</table>',
				  br(), br(),
				  submit('submit', 'Save Changes');

			close(SOP_FILE);
		}
		else { print p("Could not open file associated with the Procedure (id = $edit_id)"); return 0; }
	}
	else
	{#we are creating a new SOP
		param('name', '');
		param('file_contents', '');

		print '<table><tr><td>Name&nbsp;</td>',
			  '<td>', textfield('name', '', 30, 30), '</td></tr>',
			  '<tr><td>Procedures&nbsp;</td>',
			  '<td>', textarea('file_contents','',10,50), '</td></tr>',
			  '</table>',
			  br(), br(),
			  submit('submit', 'Create Procedure');
	}

}

sub display_private_error_page
{
	my $msg = shift;
	
	if(!$g_header)
	{
		display_title_header('FRAME2');
	}

	print p($msg);
		
	display_footer();
	
}

sub display_add_exp_wait_page
{
	my $log_file_url=shift;
	my $js="\$(document).ready(function(){check_show_results('$log_file_url');});";
	
	display_title_header('FRAME2',$js);

	# TODO 
	print p("Creating Experiment...please refresh until Success or Error message...");
	print "<div id='new_exp_result' name='new_exp_result'></div>";
	print "<button onclick=\"check_show_results('$log_file_url')\">Refresh status</button>";
	display_footer();
	
}

sub display_public_error_page
{
	my $msg = shift;
	my $display_frameset = shift;
	if ($display_frameset)
	{
		display_frameset('', 'PUBLIC', 'MESSAGE', $msg)
	}
	else
	{
		if(!$g_header)
		{
			display_title_header('PUBLIC2');
		}
	
		print p($msg);
		
	}
	

	display_footer();
}

#sub display_public_page
#{
#	my $mode = shift;
#	my $cookies_ref = shift;
#
#	display_title_header('PUBLIC', "", $cookies_ref);
#
#	if($mode eq 'LOGIN')
#	{
#		
#		display_login();
#	}
#	elsif($mode eq 'CREATE USER')
#	{
#	
#		display_create_user();
#	}
#	elsif($mode eq 'USER CREATED')
#	{
#	
#		print p("Success!  Your user account was created!");
#
#	}
#	elsif($mode eq 'SEARCH' || $mode eq 'SEARCH 2' || $mode eq 'SEARCH 3')
#	{
#	
#		if($mode eq 'SEARCH') { display_public_query_page(); }
#		elsif($mode eq 'SEARCH 2') { display_public_query_page2(); }
#		elsif($mode eq 'SEARCH 3') { display_public_query_page3(); }
#		
#	}
#	elsif($mode eq 'PUBLICVIEW SEARCH')
#	{
#		print hr();
#		display_public_query_page();
#	}
#	elsif($mode eq 'PUBLICVIEW SEARCH 2')
#	{
#		print hr();
#		display_public_query_page2();
#	}
#	elsif($mode eq 'PUBLICVIEW SEARCH 3')
#	{
#		print hr();
#		display_public_query_page3();
#	}
#	elsif($mode eq 'FAQ')
#	{
#	
#		display_faq();
#	}
#	elsif($mode eq 'HowTo')
#	{
#	
#		display_howto();
#	}
#	elsif($mode eq 'About')
#	{
#		
#		display_about();
#	}
#	elsif($mode eq 'Contact')
#	{
#		
#		display_contact();
#	}
#
#	display_footer();
#}

sub display_login
{
	print "<table><tr><td>Email:&nbsp;</td><td>",
		  textfield('email', '', 60, 60),
		  "</td></tr><tr>",
		  "<td>Password:&nbsp;</td><td>",
		  password_field('password', '', 20, 20),
		  "</td></tr></table><br>",
		  submit('submit', 'Login');
}

sub display_edit_user
{
	print <<JSPASS;

<script>
function checkPass()
{
    var pass1 = document.getElementsByName('password');
    var pass2 = document.getElementsByName('password1');
    
    if(pass1[0].value == pass2[0].value)
    {
        var form = document.getElementById('main_form');
	form.submit();
    }
    else
    {
        alert("The passwords do not match!");
    }
}
function setCancel()
{
	var ac = document.getElementsByName('action');
	ac[0].value = 'Cancel';
        var form = document.getElementById('main_form');
	form.submit();
}
</script>
JSPASS
	
	my $fname = $g_the_user -> get('First_Name');
	my $lname = $g_the_user -> get('Last_Name');
	my $inst = $g_the_user -> get('Institution');
	my $title = $g_the_user -> get('Title');
	my $orcid = $g_the_user -> get('OrcID');
	my $email = $g_the_user -> get('Email');

	#print "First Name:&nbsp;",
	#	  qq!<input type="text" name="first_name" value="$fname" size="60" maxlength="60" />!,
	#	  #textfield('first_name', '', 60, 60),
	#	  br(), br(),
	#	  "Last Name:&nbsp;",
	#	  qq!<input type="text" name="last_name" value="$lname" size="60" maxlength="60" />!,
	#	  #textfield('last_name', '', 60, 60),
	#	  br(), br(),
	#	  "ORCID:&nbsp;",
	#	  qq!<input type="text" name="orcid" value="$orcid" size="60" maxlength="60" />!,
	#	  br(), br(),
	#	  "Title:&nbsp;",
	#	  qq!<input type="text" name="title" value="$title" size="60" maxlength="60" />!,
	#	  br(), br(),
	#	  "Institution:&nbsp;",
	#	  qq!<input type="text" name="institution" value="$inst" size="60" maxlength="60" />!,
	#	  #textfield('institution', '', 60, 60),
	#	  br(), br(),
	#	  "Email:&nbsp;",
	#	  qq!<input type="text" name="email" value="$email" size="60" maxlength="60" />!,
	#	  #textfield('email', '', 60, 60),
	#	  br(), br(),
	#	  "Password:&nbsp;",
	#	  qq!<input type="password" name="password" value="     " size="20" maxlength="20" />!,
	#	  #password_field('password', '', 20, 20),
	#	  br(), br(),
	#	  submit('submit', 'Save Changes'),
	#	  br(), br(),
	#	  submit('submit', 'Cancel'),
	#	  hidden('page_type', 'user');
		  
	print "<table><tr><td>First Name:&nbsp;</td><td>",
	qq!<input type="text" name="first_name" value="$fname" size="60" maxlength="60" />!,
	"</td></tr><tr>",
	"<tr><td>Last Name:&nbsp;</td><td>",
	qq!<input type="text" name="last_name" value="$lname" size="60" maxlength="60" />!,
	"</td></tr><tr>",
	"<tr><td>ORCID:&nbsp;</td><td>",
	qq!<input type="text" name="orcid" value="$orcid" size="60" maxlength="60" />!,
	"</td></tr><tr>",
	"<tr><td>Title:&nbsp;</td><td>",
	qq!<input type="text" name="title" value="$title" size="60" maxlength="60" />!,
	"</td></tr><tr>",
	"<tr><td>Institution:&nbsp;</td><td>",
	qq!<input type="text" name="institution" value="$inst" size="60" maxlength="60" />!,
	"</td></tr><tr>",
	"<tr><td>Email:&nbsp;</td><td>",
	qq!<input type="text" name="email" value="$email" size="60" maxlength="60" />!,
	"</td></tr><tr>",
	"<tr><td>Password:&nbsp;</td><td>",
	qq!<input type="password" name="password" value="    " size="20" maxlength="20" />!,
	"</td></tr><tr>",
	"<tr><td>Re-enter password:&nbsp;</td><td>",
	qq!<input type="password" name="password1" value="    " size="20" maxlength="20" />!,
	"</td></tr></table><br>",
	"<input type='button' value='Save Changes' onclick='checkPass();'/>",
	"<input type='hidden' name='action' value='Save Changes'>",
	br(), br(),
	"<input type='button' value='Cancel' onclick='setCancel();'/>", # change hidden action to Cancel and submit
	#submit('submit', 'Cancel'),
	hidden('page_type', 'user');
		  

}
			
sub display_create_user
{
	print <<JSPASS;

<script>function checkPass()
{
    var pass1 = document.getElementsByName('password');
    var pass2 = document.getElementsByName('password1');
    
    if(pass1[0].value == pass2[0].value)
    {
        var form = document.getElementById('frm1');
	form.submit();
    }
    else
    {
        alert("The passwords do not match!");
    }
}
</script>
JSPASS
	
	print "<table><tr><td>First Name:&nbsp;</td><td>",
		  textfield('first_name', '', 60, 60),
		  "</td></tr><tr>",
		  "<tr><td>Last Name:&nbsp;</td><td>",
		  textfield('last_name', '', 60, 60),
		  "</td></tr><tr>",
		  "<tr><td>ORCID:&nbsp;</td><td>",
		  textfield('orcid', '', 60, 60),
		  "</td></tr><tr>",
		  "<tr><td>Title:&nbsp;</td><td>",
		  textfield('title', '', 60, 60),
		  "</td></tr><tr>",
		  "<tr><td>Institution:&nbsp;</td><td>",
		  textfield('institution', '', 60, 60),
		  "</td></tr><tr>",
		  "<tr><td>Email:&nbsp;</td><td>",
		  textfield('email', '', 60, 60),
		  "</td></tr><tr>",
		  "<tr><td>Password:&nbsp;</td><td>",
		  password_field('password', '', 20, 20),
		  "</td></tr><tr>",
		  "<tr><td>Re-enter password:&nbsp;</td><td>",
		  password_field('password1', '', 20, 20),
		  "</td></tr></table><br>",
		  "<input type='button' value='Create Account' onclick='checkPass();'/><input type='hidden' name='action' value='Create Account'>";
}

sub display_project_page
{
	my $id = shift;
	my $edit = shift;

	my $project = Biochemists_Dream::Project -> retrieve($id);
	
	my @users_sharing = Biochemists_Dream::Shared_Projects -> search(Project_Id=>$id);
	my $cur_user_id = $project -> get("User_Id");
	my $name = $project -> get("Name");
	my $description = $project -> get("Description");
	if (not $description) { $description = ""; }
	

	print hidden('project_parent_id', $id);

	if($edit) #($cur_user_id == $g_user_id && $edit)  # John wants to be able to edit shared projects
	{
		my @users = Biochemists_Dream::User -> retrieve_all();
		
		print h2("Edit Project:"),
			  '<table><tr><td>',
			  'Name',
			  '</td><td>',
			  qq!<input type="text" name="project_name" value="$name" size="30" maxlength="30" />!,
			  #textfield('project_name', "$name", 30, 30),
			  '</td><tr><td>',
			  'Description',
			  '</td><td>',
			  qq!<input type="text" name="project_description" value="$description" size="75" maxlength="150" />!,
			  #textfield('project_description', "$description", 150, 150),
			  '</td></tr></table>',
			  br(),br();
			  
		print 'Share this Project with:<br>';
		print qq!<select name='shared_users' size=10 multiple=True>!;
		foreach(@users)
		{
			my $cur_user_id = $_ -> get('Id');
			if($g_user_id != $cur_user_id) #can't share with self
			{
				my $cur_user_name = $_ -> get('Last_Name') . ', ' . $_ -> get('First_Name');
				my $tag = '';
				foreach my $shared (@users_sharing)
				{
					if ($cur_user_id == $shared->User_Id->Id)
					{
						$tag = "selected";
						last;
					}
					
				}
				print qq!<option value="$cur_user_id" $tag>$cur_user_name</option>!;
			}
			
			
			
		}
		print "</select>", br();
		
		print submit('submit', 'Save Changes'),
			  br(), br(),
			  submit('submit', 'Cancel'),
			  hidden('page_type', 'project');

	}
	else
	{
		my $shared_users = '';
		my $count = 0;
		foreach my $shared (@users_sharing)
		{
			my $user = Biochemists_Dream::User -> retrieve($shared->User_Id->Id);
			if($count > 0) { $shared_users .= ', '; }
			$shared_users .= $user -> get('First_Name') . ' ' . $user -> get('Last_Name');
			$count++;
		}
		if (not $shared_users) { $shared_users = "(none)"; }
		
		print h2("Project '$name'"),
			  p("Description: $description"),
			  p("Shared with: $shared_users");
			  
		if(1) #$cur_user_id == $g_user_id) # John wants to be able to edit shared projects
		{ print submit('submit', 'Edit'); }
			  
		print hidden('page_type', 'project');
	}
	
	if(1) #$cur_user_id == $g_user_id) # John wants to be able to edit shared projects
	{
		display_add_experiment($name, $cur_user_id);
	
		print "<hr>";
	
		display_add_project($name);
	}
	

	display_footer();
}

sub display_title_header
{
	my $mode = shift;
	my $js = shift;
	my $cookies_ref = shift;

	if($cookies_ref)
	{
		#add the cookies to header
		print header(-cookie => $cookies_ref);
	}
	else { print header(); }

	$g_header = 1; #notify error page that header has been displayed
	
	if($mode eq 'FRAME1')
	{
		print <<START_HTML;	
<html lang="en">
<head>
<meta charset="utf-8">
<title>copurification.org</title>
<link rel="stylesheet" href="../copurification-html/jquery-ui-1.10.1.custom.min.css">
<link rel="stylesheet" href="../copurification-html/main2.css">
<script src="../copurification-html/jquery-1.9.1.js"></script>
<script src="../copurification-html/jquery-ui-1.10.1.custom.min.js"></script>
<script src="../copurification-html/jquery.MultiFile.pack.js"></script>
<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

  ga('create', 'UA-62498626-1', 'auto');
  ga('send', 'pageview');
</script>
</head>
<body style="margin:10;">
START_HTML

		print_javascript($js); 

		print qq!<form method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" target="frame2">!,
			  h3('My Projects');
			  #hr();
	}
	elsif($mode eq 'FRAME2')
	{
		print <<START_HTML;	
<html lang="en">
<head>
<meta charset="utf-8">
<title>copurification.org</title>
<link rel="stylesheet" href="../copurification-html/jquery-ui-1.10.1.custom.min.css">
<link rel="stylesheet" href="../copurification-html/main2.css">
<script src="../copurification-html/jquery-1.9.1.js"></script>
<script src="../copurification-html/jquery-ui-1.10.1.custom.min.js"></script>
<script src="../copurification-html/jquery.MultiFile.pack.js"></script>
<script src="/copurification-html/setup6.js" type="text/javascript"></script>
<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

  ga('create', 'UA-62498626-1', 'auto');
  ga('send', 'pageview');
</script>
</head>
<body style="margin:10;">
START_HTML
		print_javascript($js); 
		  
	}
	elsif($mode eq 'FRAME3')
	{
		print <<START_HTML;	
<html lang="en">
<head>
<meta charset="utf-8">
<title>copurification.org</title>
<link rel="stylesheet" href="../copurification-html/jquery-ui-1.10.1.custom.min.css">
<link rel="stylesheet" href="../copurification-html/header.css">
<script src="../copurification-html/jquery-1.9.1.js"></script>
<script src="../copurification-html/jquery-ui-1.10.1.custom.min.js"></script>
<script src="../copurification-html/jquery.MultiFile.pack.js"></script>
<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

  ga('create', 'UA-62498626-1', 'auto');
  ga('send', 'pageview');
</script>
</head>
<body style="margin:10;">
START_HTML
		print_javascript($js); 
		
		#get user info for logged in message
		my $first_name = $g_the_user -> get('First_Name');
		my $last_name = $g_the_user -> get('Last_Name');
		my $email = $g_the_user -> get('Email');

		print 	qq!<h2 style="display:inline">copurification.org</h2>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Logged in: $first_name $last_name ($email)<br><br>!,
				qq!<form method="post" action="/copurification-cgi/copurification.pl" enctype="multipart/form-data" target="frame3">!,
				qq!<a href="../copurification-cgi/copurification.pl?submit=OpenPublicView" target="frame2">Search Public Gels</a>!, 
				"&nbsp;|&nbsp;",
				a({href=>"../copurification-cgi/copurification.pl?frame=2", target=>'frame2'}, "New Project"),
				"&nbsp;|&nbsp;",
				a({href=>"../copurification-cgi/copurification.pl?frame=2;submit=Edit;page_type=user", target=>'frame2'}, "My Account"),
				"&nbsp;|&nbsp;",
				a({href=>"../copurification-cgi/copurification.pl?frame=2;submit=MyProcedures", target=>'frame2'}, "Manage Files"),
				"&nbsp;|&nbsp;",
				a({href=>"../copurification-html/HowTo.html", target=>'frame2'}, "HOWTO"),
				"&nbsp;|&nbsp;",
				a({href=>"../copurification-html/FAQ.html", target=>'frame2'}, "FAQ"),
				"&nbsp;|&nbsp;",
				a({href=>"../copurification-html/About.html", target=>'frame2'}, "About"),
				"&nbsp;|&nbsp;",
				a({href=>"../copurification-cgi/copurification.pl?frame=2;submit=Contact", target=>'frame2'}, "Contact"),
				"&nbsp;|&nbsp;",
				a({href=>"../copurification-cgi/copurification.pl?frame=2;submit=Logout", target=>'_parent'}, "Logout");
			
		
	}
	elsif($mode eq 'PUBLIC1')
	{
		print <<START_HTML;	
<html lang="en">
<head>
<meta charset="utf-8">
<title>copurification.org</title>
<link rel="stylesheet" href="../copurification-html/jquery-ui-1.10.1.custom.min.css">
<link rel="stylesheet" href="../copurification-html/header.css">
<script src="../copurification-html/jquery-1.9.1.js"></script>
<script src="../copurification-html/jquery-ui-1.10.1.custom.min.js"></script>
<script src="../copurification-html/jquery.MultiFile.pack.js"></script>
<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

  ga('create', 'UA-62498626-1', 'auto');
  ga('send', 'pageview');

</script>
</head>
<body style="margin:10;">
START_HTML
		print_javascript($js); 
		print h2('copurification.org');
	}
	elsif($mode eq 'PUBLIC2')
	{
		print <<START_HTML;	
<html lang="en">
<head>
<meta charset="utf-8">
<title>copurification.org</title>
<link rel="stylesheet" href="../copurification-html/jquery-ui-1.10.1.custom.min.css">
<link rel="stylesheet" href="../copurification-html/main2.css">
<script src="../copurification-html/jquery-1.9.1.js"></script>
<script src="../copurification-html/jquery-ui-1.10.1.custom.min.js"></script>
<script src="../copurification-html/jquery.MultiFile.pack.js"></script>
<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

  ga('create', 'UA-62498626-1', 'auto');
  ga('send', 'pageview');

</script>
</head>
<body style="margin:10;">
START_HTML
		print_javascript($js); 
		
	}
	else
	{
		print <<START_HTML;	
<html lang="en">
<head>
<meta charset="utf-8">
<title>copurification.org</title>
<link rel="stylesheet" href="../copurification-html/jquery-ui-1.10.1.custom.min.css">
<link rel="stylesheet" href="../copurification-html/main2.css">
<script src="../copurification-html/jquery-1.9.1.js"></script>
<script src="../copurification-html/jquery-ui-1.10.1.custom.min.js"></script>
<script src="../copurification-html/jquery.MultiFile.pack.js"></script>
<script src="/copurification-html/setup_search_results.js" type="text/javascript"></script>
<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

  ga('create', 'UA-62498626-1', 'auto');
  ga('send', 'pageview');

</script>
</head>
<body style="margin:10;">
START_HTML
		print_javascript($js); 
	}
}

sub display_public_frame1_error_page
{
	my $msg = shift;

	if(!$g_header)
	{ display_title_header('PUBFRAME1'); }

	print "<table><tr><td>Error loading gels: $msg</td></tr></table>";

	display_footer();
}

sub display_frame1_error_page
{
	my $msg = shift;

	if(!$g_header)
	{ display_title_header('FRAME1'); }

	print "<table><tr><td>Error loading projects: $msg</td></tr></table>";

	display_footer();
}

sub display_gel_details
{
	my $gel = shift;
	my $user_id = shift;
	my $img_str = shift;
	
	my $style_str0 = '';
	my $style_str1=qq!style="display:none"!;
	my $style_str2=qq!style="display:none"!;
	my $style_str3=qq!style="display:none"!;
	if ($img_str eq '-n')
	{
        $style_str0 = qq!style="display:none"!;
		$style_str1='';
    }
	elsif($img_str eq '-nn')
	{
		$style_str0 = qq!style="display:none"!;
		$style_str2='';
	}
	elsif($img_str eq '-nnn')
	{
		$style_str0 = qq!style="display:none"!;
		$style_str3='';
		
	}
	
	my $exp_id = $gel -> get("Experiment_Id");
	my $gel_num = $gel -> get("File_Id");
	my $gel_type = $gel -> get("File_Type");
	
	my $gel_id = $gel -> get('Id');
	my $public = $gel -> get('Public');
	my $err_description = $gel -> get('Error_Description');
	my $display_name = $gel -> get('Display_Name');
	my $date = $gel -> get('Date_Submitted');

	my @lanes = $gel -> lanes(); 
	my @table_rows;
	my @cur_cols;
	my $units = "";
	
#	add ms database pop up
	print qq!<div id="gel-$gel_id">!;
	
	##print qq!<input type="hidden" id="Exp_Id_for_Popup" name="Exp_Id_for_Popup" value="$exp_id">!;	
	###print qq!<input type="hidden" id="Gel_No_for_Popup" name="Gel_No_for_Popup" value="$gel_num">!;
	###print qq!<input type="hidden" id="Gel_Id_for_Popup" name="Gel_Id_for_Popup" value="$gel_id">!;
	###print qq!<input type="hidden" id="Lane_Order_for_Popup" name="Lane_Order_for_Popup" value="">!; moved into subroutine was clearing out the data
	###print qq!<input type="hidden" id="Band_Id_for_Popup" name="Band_Id_for_Popup" value="">!;
	###print qq!<input type="hidden" id="Band_Id_for_File" name="Band_Id_for_File" value="">!;
	##print qq!<input type="hidden" id="band_or_lane" name="band_or_lane" value="lane">!;
	##print qq!<input type="hidden" id="update_or_delete" name="update_or_delete" value="">!;
	##print qq!<input type="hidden" id="Protein_Id_for_Rollover" name="Protein_Id_for_Rollover" value="">!;
	##
	##print qq!<input type="hidden" id="Redisplay_Lane_Popup" name="Redisplay_Lane_Popup" value="No">!;
	##print qq!<input type="hidden" id="Redisplay_Current_Lane_Data" name="Redisplay_Current_Lane_Data" value="No">!;
	##print qq!<input type="hidden" id="Redisplay_Band_Popup" name="Redisplay_Band_Popup" value="No">!;
	##print qq!<input type="hidden" id="Cur_Systematic_Name_For_Band" name="Cur_Systematic_Name_For_Band">!;
	##print qq!<input type="hidden" id="Save_Lane_Order_for_Band_Processing" name="Save_Lane_Order_for_Band_Processing">!;
	##
	##create_ms_search_engine_html ($display_name);
	##create_add_protein_to_band_html ();
	
	print qq!<br>!;
	
	my $Shared_Project = 0;
	if($g_user_id != $user_id) {$Shared_Project = 1;}
	
	my $display_name_ = $display_name;
	$display_name_ =~ s/\'//g;
	$display_name_ =~ s/\"//g;
	
	foreach my $lane (@lanes)
	{
		my $is_qty_cal = $lane -> get('Quantity_Std_Cal_Lane');
		if($is_qty_cal) { $units = $lane -> get('Quantity_Std_Units'); }
		my $lane_order = $lane -> get("Lane_Order");
		
		my $show_current_data = 0; # 1 = yes
		my $lane_title = "";
		my $lane_color;
		
		my $ms_search_engine = $lane -> get("MS_Search_Engine");
		my $experiment_dir;
		my $local_ms_fname;
		my $local_fname;
		my $MS_File_Suffix;
		my $xml_file=0;
		#if found add to title for mouse rollover - BA2016
		if (defined $ms_search_engine)
		{
			$show_current_data = 1; # 1 = yes
			$lane_color = "green";
			$lane_title = "Search Engine: $ms_search_engine";
			$MS_File_Suffix = $lane -> get("MS_File_Suffix");
			if (defined $MS_File_Suffix)
			{
				if ((lc $MS_File_Suffix) eq "xml") { $xml_file=1; }
                
				#my $experiment_dir = "/copurification/$g_user_id/Experiments";
				my $experiment_dir = "/copurification/$user_id/Experiments";
				$local_ms_fname = "gel$gel_num.lane.$lane_order.ms";
				$local_fname = "$experiment_dir/$exp_id/$local_ms_fname.$MS_File_Suffix";
			}
			else { print DEVEL_OUT "MS File Suffix could not be found.  Something is wrong!\n"; } 
		}
		else
		{
			$ms_search_engine = " ";
			$local_fname = " ";
			$lane_color = "blue";
		}		
		$ms_search_engine = "\'" . $ms_search_engine . "\'";
 		push @cur_cols, qq!<a id="popup_for_lane$gel_num\_$lane_order" title="$lane_title" style="color: $lane_color" onclick="show_popup_for_lane('Add MS Database to Lane',$gel_id,$gel_num,\'$display_name_\',$lane_order,$show_current_data,$ms_search_engine,&quot;$local_fname&quot;,$Shared_Project,$xml_file)" href="#Add MS Database to Lane">$lane_order</a>!;
	}

	push @table_rows, th(\@cur_cols); #th(['Lane', 'Bands (masses, kDa)']);

	@cur_cols = ();
	my $Switch_Color;
	foreach my $lane (@lanes)
	{
		my @bands = $lane -> bands();
		my $lane_order = $lane -> get("Lane_Order");
		my $lane_id = $lane -> get('Id');
		
		if(!$err_description && @bands)
		{#dont show mass/amounts if there's an error in processing the gel or the bands were not quantified
			
		 	my $html_str = create_imagemap_html_for_gel(\@bands, $lane_id, $units, $lane_order, $gel_num, $display_name_, $exp_id, $Shared_Project, $user_id);
			print $html_str;
		}
		#output lane image...also, output normalized image, but hide it:
		$Switch_Color = param_check('switch_color');
		
		push @cur_cols, qq!<div name="lane_image" $style_str0><img class="lane_img" id="$gel_id-$lane_id" onload="update_lane_color_for_band('popup_for_lane$gel_num\_$lane_order', $Switch_Color)" src="/copurification/$user_id/Experiments/$exp_id/gel$gel_num.lane.$lane_order.png"; usemap="#$lane_id"></div>\
			       <div name="norm_lane_image" $style_str1><img class="lane_img" id="$gel_id-$lane_id-n" src="/copurification/$user_id/Experiments/$exp_id/gel$gel_num.lane.$lane_order.n.png"; usemap="#$lane_id"></div>\
			       <div name="norm_lane_image2" $style_str2><img class="lane_img" id="$gel_id-$lane_id-nn" src="/copurification/$user_id/Experiments/$exp_id/gel$gel_num.lane.$lane_order.nn.png"; usemap="#$lane_id"></div>\
				   <div name="norm_lane_image3" $style_str3><img class="lane_img" id="$gel_id-$lane_id-nnn" src="/copurification/$user_id/Experiments/$exp_id/gel$gel_num.lane.$lane_order.nnn.png"; usemap="#$lane_id"></div>!;
	}
	push @table_rows, td(\@cur_cols);

	if($public) { print "Gel $display_name, submitted on $date ($gel_type file) PUBLIC GEL"; }
	#cant make gel public if it has an error in processing
	elsif($err_description){ print "Gel $display_name, submitted on $date ($gel_type file) *Gel has a processing error: $err_description*"; }
	else
	{
		if ($g_user_id == $user_id)
		{
			print qq!<input type='checkbox' name='gels_public' value="$gel_id">Gel $display_name, submitted on $date ($gel_type file)</input>!;
		}
		else
		{
			print qq!Gel $display_name, submitted on $date ($gel_type file)!;
		}
		
	}
	print br();
	#print "&nbsp;&nbsp;&nbsp;&nbsp;";
	print qq!<button type="button" disabled id="save_bands_gel-$gel_id" name="save_bands_gel-$gel_id" class="save_bands_button">Save Bands</button>!;
	print "&nbsp;&nbsp;&nbsp;";
	print qq!<button type="button" disabled id="clear_bands_gel-$gel_id" name="clear_bands_gel-$gel_id" class="clear_bands_button">Clear Bands</button>!;
	
	print br(),br();
	print table({-border=>0, -rules=>'cols'}, caption(""), Tr({-align=>'CENTER', -valign=>'TOP'}, \@table_rows));
	print qq!</div>!;
}

sub create_ms_search_engine_html 
{
	my $display_name_ = shift;	
	$display_name_ =~ s/\'//g;
	$display_name_ =~ s/\"//g;
	
	#redisplay logic
	my @params = param_check();
	my $Redisplay_Lane_Popup = param_check('Redisplay_Lane_Popup');
	my $Gel_No = param_check('Gel_No_for_Popup'); #do I need this here?
	my $Lane_Order = param_check('Lane_Order_for_Popup');
	my $Gel_Name = param_check("Gel_Id_for_Popup");

	my $display_lane_popup;
	my $lane_gel_id;
	my $lane_lane_order;
	my $lane_popup_error_message;
	#
	my $display_current_lane_data;
	my $display_lane_delete;
	my $redisplay_search_engine;
	my $redisplay_results_file;
	if (0) { #$Redisplay_Lane_Popup eq "Yes") {
		$display_lane_popup = "";
		$display_lane_delete  = "";
		$lane_gel_id = $Gel_No;
		$lane_lane_order = $Lane_Order;
		$lane_popup_error_message = param ('Lane_Popup_Error_Message');;
		#$lane_popup_error_message = "The MS Results File has a bad file extension.  Please select another file.";
		# Display current data if it exists
		$redisplay_search_engine = param ('Redisplay_Cur_Search_Engine');
		if ($redisplay_search_engine) {
			$redisplay_results_file = param ('Redisplay_Cur_Results_File');
			$display_current_lane_data = "";		
			$display_lane_delete  = "";
		} else {
			$display_current_lane_data = "none";
			$display_lane_delete  = "none";
			$redisplay_search_engine = "?eng";
			$redisplay_results_file = "";
		}
		#
		print qq!<input type="hidden" id="Lane_Order_for_Popup" name="Lane_Order_for_Popup" value="$Lane_Order">!;
	}
	else {
		$display_lane_popup = "none";
		$display_lane_delete  = "none";
		$lane_gel_id = "?";
		$lane_lane_order = "?";
		$lane_popup_error_message =" ";
		#
		$display_current_lane_data = "none";
		$redisplay_search_engine = "?eng";
		$redisplay_results_file = "";
		#
		#print qq!<input type="hidden" id="Lane_Order_for_Popup" name="Lane_Order_for_Popup" value="">!;
	}
	
	print qq!<div id="Add MS Database to Lane" style="display: $display_lane_popup">!;
	print qq!<h4 id='Lane Popup Header'>For Gel <span id='Gel_Id_for_Display' name='Gel_Id_for_Display'>$display_name_</span>, Lane <span id='LaneOrder' name='LaneOrder'>$lane_lane_order</span></h4>!;
	print qq!<table id="Display Existing Lane Info" style="width: 100%;margin-top: 10px;margin-left: 0px; border-style: solid;  display: $display_current_lane_data">!;
	print qq!<tr>!;
	print qq!  <td>Current Data: </td>!;
	print qq!</tr>!;
	print qq!<tr>!;
	print qq!  <td>Current MS Search Engine: </td>!;
	print qq!  <td><span id='cur_ms_search_engine' name='cur_ms_search_engine'>$redisplay_search_engine</span></td>!;
	print qq!</tr>!;
	print qq!<tr>!;
	print qq!  <td>Click to view current mass spec file: </td>!;
 	print qq!  <td><a  id='cur_local_ms_file'  name='cur_local_ms_file' href="$redisplay_results_file" target="_blank">MS Search Results File</a></td>!;
	print qq!</tr>!;
	print qq!</table>!;

	print qq!<table id="Lane Input Panel" style="width: 100%;margin-top: 10px;margin-left: 0px; border-style: solid;">!;
	print qq!<tr>!;
	print qq!  <td>MS Search Engine: </td>!;
	print qq!  <td><select id="ms_search_engine" name="ms_search_engine">!;
	print qq! 		 <option id="Xtandem" value="Xtandem">XTandem</option>!;
	print qq!  		 <option value="SEQUEST">SEQUEST</option>!;
	print qq!  		 <option value="Mascot">Mascot</option>!;
	print qq!  		 <option value="MSGFplus">MSGFplus</option>!;
	print qq!  		 <option value="Andromeda">Andromeda</option>!;
	print qq!	   </select>!;
	print qq!  </td>!;
	print qq!</tr>!;

	print qq!<tr>!;
	print qq!  <td>MS Search Results File: </td>!;
	print qq!  <td><input type="file" name="mass_spect_file" id="mass_spect_file"></td>!;
	#print qq!<span id='info_message_for_lane_file' style="display: none">(leave blank to keep current file)</span></td>!;
	print qq!</tr>!;
	
	print qq!<tr>!;
	print qq!  <td>!;
	print qq!    <input type="Submit" id="addMassSpectButton" name="submit" value="Save MS Data" onclick="addMassSpectData('lane','Update');">!;
	print qq!    <input type="Submit" id="delMassSpectButton" name="submit" value="Del MS Data" style="display: $display_lane_delete" onclick="addMassSpectData('lane','Delete');">!;
	print qq!    <input type="button" value="Close" onclick="hide_popup_for_lane('Add MS Database to Lane')">!;
	print qq!  </td>!;
	print qq!</tr>!;
	print qq!<tr>!;
	print qq!  <td>!;
	print qq!<span id='error_message_for_lane_popup' style="display: $display_lane_popup">$lane_popup_error_message</span>!;
	print qq!  </td>!;
	print qq!</tr>!;
	
	print qq!</table>!;

print qq!</div>!;
}

sub create_add_protein_to_band_html   
{
	my $display_name_ = shift;	
	$display_name_ =~ s/\'//g;
	$display_name_ =~ s/\"//g;
	
	#redisplay logic
	my @params = param_check();
	my $Exp_Id = param_check('Exp_Id_for_Popup');
	my $Redisplay_Band_Popup = param_check('Redisplay_Band_Popup');
	my $Gel_No = param_check('Gel_No_for_Popup'); 
	my $Lane_Order = param_check('Lane_Order_for_Popup');
	my $Band_Mass = param_check('Band_Mass_for_Popup');
	my $Band_Id_for_Popup = param_check('Band_Id_for_Popup');
	my $Band_Id_for_File = param_check('Band_Id_for_File');
	my $select1; #Western Blot
	my $select2; #Mass Spec
	my $select3; #Mass Spec
	#print DEVEL_OUT " value for Lane Order $Lane_Order\n";
	#must save Lane Id for iterations
	#param_check('Save_Lane_Order_for_Band_Processing', $Lane_Order);
	my $test = param_check('Save_Lane_Order_for_Band_Processing');
	#print DEVEL_OUT "THE SAVED LANE IS $test\n";
	
	my $display_band_popup;
	my $display_mass_spect_input;
	my $band_gel_id;
	my $band_lane_order;
	my $band_mass_for_display;
	my $ms_protein_name;
	my $band_popup_error_message;
	my $display_current_band_data;
	my $display_band_delete ='none';

	#must retrieve band_protein to get current information if it exists
	my @band_protein = Biochemists_Dream::Band_Protein -> search(Band_Id => $Band_Id_for_File);
	my $band = Biochemists_Dream::Band -> retrieve($Band_Id_for_File);
	my $Cur_Protein_ID;
	my $Cur_Search_Engine="";
	my $Cur_Protein_ID_Method="";
	my $Cur_MS_File_Suffix="";
	my $Cur_Systematic_Name_For_Band="";
	my $Cur_MS_Results_File;
	my $Display_Cur_MS_Search_Data;
	my $Cur_Verified=""; 
	if(defined($band))
	{
		my $Cur_Verified = $band -> get("Used_for_Protein_ID");
		if($Cur_Verified == 1) {$Cur_Verified="Yes";}
		else {$Cur_Verified="No";}
	}
	
	foreach my $band_protein (@band_protein)
	{
		#must get extension from band_protein (note - must clear that out also)
		$Cur_Protein_ID = $band_protein -> get("Protein_ID");
		$Cur_Search_Engine = $band_protein -> get("MS_Search_engine");
		$Cur_Protein_ID_Method = $band_protein -> get("Protein_ID_Method");
		$Cur_MS_File_Suffix = $band_protein -> get("MS_File_Suffix");
	}
		
	$Cur_Systematic_Name_For_Band = param_check('Cur_Systematic_Name_For_Band');
	my $experiment_dir = "/copurification/$g_user_id/Experiments";
	my $local_ms_fname = "gel$Gel_No.lane.$Lane_Order.band.$Band_Id_for_File.ms";
	$Cur_MS_Results_File = "$experiment_dir/$Exp_Id/$local_ms_fname.$Cur_MS_File_Suffix";

	if (0) #$Redisplay_Band_Popup eq "Yes")
	{
		#print DEVEL_OUT "ARE WE REDISPLAYING??????????";
		$display_band_popup = "";
		my $check_for_ms = param ('Turn_On_MS_Input'); #this is to make sure the input fields remain turned on
		my $ms_protein_id_method = lc(param_check('ms_protein_id_method')); 
		if ($check_for_ms eq "Yes")
		{
			$display_mass_spect_input = "";
#			print DEVEL_OUT "id method is $ms_protein_id_method";
#			$select1 = ''; 		#Western Blot
#			$select2 = 'selected'; 	#Mass Spec
		}
		else
		{
			$display_mass_spect_input = "none";
#			print DEVEL_OUT "id method is $ms_protein_id_method";
#			$select1 = 'selected'; 	#Western Blot
#			$select2 = ''; 		#Mass Spec
		}
		#print DEVEL_OUT "\nid method is $ms_protein_id_method\n";
		if 	($ms_protein_id_method eq "mass spec") {
			$select1 = ''; 			#Western Blot
			$select2 = 'selected'; 		#Mass Spec
			$select3 = ''; 			#Other
		} elsif ($ms_protein_id_method eq "western blot") {
			$select1 = 'selected'; 		#Western Blot
			$select2 = ''; 			#Mass Spec
			$select3 = ''; 			#Other
		} elsif ($ms_protein_id_method eq "other") {
			$select1 = ''; 			#Western Blot
			$select2 = ''; 			#Mass Spec
			$select3 = 'selected'; 		#Other
		}
			
		# for current data there is always a protein and protein id method
		# only turn on MS portion if it exists that is current protein id method is Mass Spec
		if ($Cur_Protein_ID_Method)
		{
			$display_current_band_data = ''; # display whole current panel
			$display_band_delete = ''; #display delete button
			if ($Cur_Search_Engine eq undef) {$Display_Cur_MS_Search_Data = 'none';} # do not display current MS portion
			else {$Display_Cur_MS_Search_Data = '';} # display current MS portion
		}
		else
		{
			$display_current_band_data = "none";
			$Display_Cur_MS_Search_Data = "none";
			$display_band_delete ='none';
		}
		
		$band_gel_id = $Gel_No;
		$band_lane_order = $Lane_Order;
		$band_mass_for_display = $Band_Mass;
		$ms_protein_name = param ('ms_protein_name');
		#print DEVEL_OUT "\nprotein name  for display is $ms_protein_name\n";
		$band_popup_error_message = param ('Band_Popup_Error_Message');
		print qq!<input type="hidden" id="Lane_Order_for_Popup" name="Lane_Order_for_Popup" value="$Lane_Order">!;
		print qq!<input type="hidden" id="Band_Mass_for_Popup" name="Band_Mass_for_Popup" value="$Band_Mass">!;
		print qq!<input type="hidden" id="Band_Id_for_Popup" name="Band_Id_for_Popup" value="$Band_Id_for_Popup">!;
		print qq!<input type="hidden" id="Band_Id_for_File" name="Band_Id_for_File" value="$Band_Id_for_File">!;
	}
	else
	{
		$display_band_popup = "none"; # changed from none 07/15/2016
		$display_mass_spect_input = "none"; # changed from none 07/15/2016
		$band_gel_id = "";
		$band_lane_order = "";
		$band_mass_for_display = "";
		$ms_protein_name = "";
		$band_popup_error_message = "";
		$Display_Cur_MS_Search_Data = "none";
		print qq!<input type="hidden" id="Lane_Order_for_Popup" name="Lane_Order_for_Popup" value="">!;
		print qq!<input type="hidden" id="Band_Mass_for_Popup" name="Band_Mass_for_Popup" value="">!;
		print qq!<input type="hidden" id="Band_Id_for_Popup" name="Band_Mass_for_Popup" value="">!;
		print qq!<input type="hidden" id="Band_Id_for_File" name="Band_Id_for_File" value="">!;
	}
	#print DEVEL_OUT " value for Lane Order $Lane_Order\n";
	#must save Lane Id for iterations
	#param_check('Save_Lane_Order_for_Band_Processing', $Lane_Order);
	$test = param_check('Save_Lane_Order_for_Band_Processing');
	#print DEVEL_OUT "THE SAVED LANE IS $test\n";
	
	#print qq!<div  id="Add MS Protein to Band" style="display: none">!;
	print qq!<div  id="Add MS Protein to Band" style="display: $display_band_popup">!;
	print qq!<h4 id='Band Popup Header'>For Gel <span id='GelIdforBand'>$display_name_</span>, Lane <span id='LaneOrderforBand'>$band_lane_order</span>, for Band Mass <span id='Band_Mass_for_Display'>$band_mass_for_display</span> kDa: </h4>!;

	print qq!<table id="Display Existing Band Info" style="width: 100%;margin-top: 10px;margin-left: 0px; border-style: solid;  display: $display_current_band_data;">!;
	print qq!<tr>!;
	print qq!  <td>Current Data: </td>!;
	print qq!</tr>!;
	print qq!<tr>!;
	print qq!  <td>Current protein associated with band: </td>!;
	print qq!  <td><span id='cur_band_protein'>$Cur_Systematic_Name_For_Band</span></td>!;
	print qq!</tr>!;
	print qq!<tr>!;
	print qq!  <td>Current protein id method: </td>!;
	print qq!  <td><span id='cur_protein_id_method'>$Cur_Protein_ID_Method</span></td>!;
	print qq!</tr>!;
	
	print qq!<tr id="cur ms spect engine display for band" style="display: $Display_Cur_MS_Search_Data">!;
	print qq!  <td>Current MS Search Engine: </td>!;
	print qq!  <td><span id='cur_ms_search_engine_for_band'>$Cur_Search_Engine</span></td>!;
	print qq!</tr>!;
	
	print qq!<tr id="cur ms spect file display for band" style="display: $Display_Cur_MS_Search_Data">!;
	print qq!  <td>Click to view current MS Search Results File: </td>!;
 	print qq!  <td><a  id='cur_local_ms_file_for_band' href="$Cur_MS_Results_File" target="_blank">MS Search Results File</a></td>!;
	print qq!</tr>!;
	
	print qq!<tr>!;
	print qq!  <td>Was this particular band was used to identify protein? </td>!;
 	print qq!  <td><span id='cur_verified_on_this_gel'>$Cur_Verified</span></td>!;
	print qq!</tr>!;
	
	print qq!</table>!;

	print qq!<table id="Band Input Panel" style="width: 100%;margin-top: 10px;margin-left: 0px;border-style: solid;">!;
	print qq!<tr>!;
	print qq!<td>Protein associated with this band: </td>!;
	print qq!<td><input id="ms_protein_name" type="text" name="ms_protein_name" value=$ms_protein_name ></td>!;
	print qq!</tr>!;
	
	print qq!<tr>!;
	print qq!  <td>Protein id method used for this band: </td>!;
	print qq!  <td><select Id="ms_protein_id_method" name="ms_protein_id_method"   onchange="display_updates_for_band()">!;
	print qq! 		 <option Id="mass spec" value="mass spec" $select2>mass spec</option>!;
	print qq!  		 <option Id="Western Blot" value="Western Blot" $select1>western blot</option>!;
	print qq!  		 <option value="Other" $select3>other</option>!;
	print qq!	   </select>!;
	print qq!  </td>!;
	print qq!</tr>!;
 
	#these two inputs are displayed only when Mass Spec for Protein Id Method is chosen
	print qq!<tr id="ms spect engine display for band" style="display: $display_mass_spect_input">!;
	print qq!<td>MS Search Engine used: </td>!;
	print qq!  <td><select id="ms_search_engine_for_band" name="ms_search_engine_for_band">!;
	print qq! 		 <option id="Xtandem" value="Xtandem">Xtandem</option>!;
	print qq!  		 <option value="SEQUEST">SEQUEST</option>!;
	print qq!  		 <option value="Mascot">Mascot</option>!;
	print qq!  		 <option value="MSGFplus">MSGFplus</option>!;
	print qq!  		 <option value="Andromeda">Andromeda</option>!;
	print qq!	   </select>!;
	print qq!  </td>!;
	print qq!</tr>!;
	
	print qq!<tr id="ms spect file display for band" style="display: $display_mass_spect_input">!;
	print qq!<td>Upload MS Search Results File: </td>!;
	print qq!<td><input type="file" name="mass_spect_file_for_band" id="mass_spect_file_for_band"></td>!;
	#print qq!<font style="font-size: 90%"><span id='info_message_for_band_file' >(leave blank to keep current file)</span></font></td>!;
	print qq!</tr>!;
	#only when needed
	
	print qq!<tr>!;
	print qq!<td>Was this particular band used to identify the protein? </td>!;
	print qq!<td><input type="radio" id="verified_on_this_gel_yes" name="verified_on_this_gel" value="Yes" checked>Yes <input type="radio" id="verified_on_this_gel_no" name="verified_on_this_gel" value="No">No <b><a href="../copurification-html/HowTo.html#AddDataToBand" target="_blank">?</a></b></td>!;
	print qq!</tr>!;
	
	print qq!<tr>!;
	print qq!<td><input type="checkbox" id="propogate_label" name="propogate_label" value="propogate_label"> Propogate this label across lanes</td>!;
	print qq!<td>&nbsp;</td>!;
	print qq!</tr>!;
	
	print qq!<tr>!;
	print qq!<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Mass range for band: +/- <input id="propogate_label_mass_range" type="text" name="propogate_label_mass_range" value=0.5 size=5> kDa</td>!;
	print qq!<td>&nbsp;</td>!;
	print qq!</tr>!;
	
	print qq!<tr>!;
	print qq!  <td>!;
	#added lane order for testing error redisplay bug must retest
	print qq!    <input type="submit" id="addMassSpectButton2" name="submit" value="Save MS Data" onclick="addMassSpectData('band','Update');">!;
	print qq!    <input type="submit" id="delMassSpectButton2" name="submit" value="Del MS Data" onclick="addMassSpectData('band','Delete');" style="display: $display_band_delete">!;
	print qq!    <input type="button" value="Close" onclick="hide_popup_for_band('Add MS Protein to Band')">!;
	print qq!  </td>!;
	print qq!<td>&nbsp;</td>!;
	print qq!</tr>!;
	
	print qq!<tr>!;
	print qq!  <td>!;
		print qq!<span id='error_message_for_band_popup' style="display: $display_band_popup;color: red">$band_popup_error_message</span>!;
	print qq!  </td>!;
	print qq!<td>&nbsp;</td>!;
	print qq!</tr>!;
	
	print qq!</table>!;
	
	print qq!</div>!;
}


#create_imagemap_html_for_search(\@bands, $lane_id, $units, $lane_order, $gel_num, $exp_id, $user_id);
sub create_imagemap_html_for_search
{
	my $bands_ref = shift;
	my $lane_id = shift;
	my $units = shift;
	my $lane_order = shift;
	my $gel_num=shift;
	my $exp_id = shift;
	my $user_id=shift;
	
	my $ret_string = qq!<map name="$lane_id">!;
	
	my ($data_source, $db_name, $user, $password) = getConfig();
	my $dbh = DBI->connect($data_source, $user, $password, { RaiseError => 1, AutoCommit => 0 });
	my $sql = 'SELECT Protein_Id, MS_Search_Engine, Protein_Id_Method, MS_File_Suffix FROM band_protein WHERE Band_Id = ?';
 	my $sth = $dbh->prepare($sql);
		
	foreach (@{$bands_ref})
	{
		my $band_id = $_ -> get ('Id'); 
		my $mass = $_ -> get('Mass') || "";
		my $amount = $_ -> get('Quantity') || "";
		my $st = $_ -> get('Start_Position');
		my $end = $_ -> get('End_Position');
		
		$sth->execute($band_id) or die "retrieve band error code: ", $DBI::errstr;
		my $row_count = $sth->rows;
		my $protein_count=0;
		my $common_name_list = ""; my $search_engine=''; my $id_method=''; my $file_suffix='';
		if ($row_count > 0)
		{ # more than one protein can be added, but the associated Protein ID method etc information is the same 
			while ( my @row = $sth->fetchrow_array )
			{
				my $protein_id;
				if ($protein_count == 0)
				{ ($protein_id, $search_engine, $id_method, $file_suffix) = @row; }
				else{ $protein_id = $row[0]; }
                
				my $protein_db_entry = Biochemists_Dream::Protein_DB_Entry -> retrieve($protein_id);
				if ($protein_count == 0) { $common_name_list .= $protein_db_entry -> get("Common_Name"); }
				else { $common_name_list .= ("," . $protein_db_entry -> get("Common_Name")); }
				$protein_count++;
			}
		}
		
		my $title;
		if($amount) { $title = "Mass: $mass kDa, Quantity: $amount $units"; }
		else { $title = "Mass: $mass kDa"; }
		
		if ($protein_count > 0)
		{
            $title =  $title . ", Common Name: $common_name_list";
			if ($id_method) { $title = $title . ", Id Method: $id_method"; }
			if ($search_engine) { $title = $title . ", Search Engine: $search_engine"; }
        }
		
		if($st && $end)
 		{
			$ret_string .= qq!<area shape="rect" coords="0,$st,25,$end" !;
			
			if ($protein_count > 0 && $file_suffix)
			{
				my $experiment_dir = "http://$HOSTNAME/copurification/$user_id/Experiments";						
				my $local_ms_fname = "gel$gel_num.lane.$lane_order.band.$band_id.ms";	
				my $local_fname = "$experiment_dir/$exp_id/$local_ms_fname.$file_suffix";
		
				if ((lc $file_suffix) eq 'xml')
				{
					$ret_string .= qq!href="$local_fname" download="xml_file" title="$title" style="cursor:crosshair;" />!; 	
				}
				else
				{
					$ret_string .= qq!href="$local_fname" target="_blank" title="$title" style="cursor:crosshair;" />!; 	
				}
				     
			}
			else
			{
				$ret_string .= qq!title="$title" style="cursor:crosshair;" />!; 	
			}
		}
	}
	
	$ret_string .= qq!</map>!;

	$sth->finish();
	$dbh->disconnect();
			
	return $ret_string;
	
}

#create_imagemap_html_for_gel(\@bands, $lane_id, $units, $lane_order, $gel_num, $display_name_, $exp_id, $Shared_Project, $user_id);
sub create_imagemap_html_for_gel
{
	my $bands_ref = shift;
	my $lane_id = shift;
	my $units = shift;
	my $lane_order = shift;
	
	my $gel_num = shift;
	my $gel_name = shift;
	my $exp_id = shift;
	my $Shared_Project = shift;
	my $user_id = shift;
    
	my $ret_string = qq!<map name="$lane_id">!;
	my $Id_Method_for_Rollover;
	my $Search_Engine_for_Rollover;
	my $Protein_Id_for_Rollover;
	my $Systematic_Name_for_Rollover;
	my $Common_Name_for_Rollover;
	my $MS_File_Suffix;
	my $has_band_been_assigned_protein = 0;
	
	my ($data_source, $db_name, $user, $password) = getConfig();
	my $dbh = DBI->connect($data_source, $user, $password, { RaiseError => 1, AutoCommit => 0 });
	my $sql = 'SELECT Protein_Id, MS_Search_Engine, Protein_Id_Method, MS_File_Suffix FROM band_protein WHERE Band_Id = ?';
 	my $sth = $dbh->prepare($sql);
		
	foreach (@{$bands_ref})
	{
		my $Band_Id_for_Popup = $_ -> get ('Id'); 
		my $mass = $_ -> get('Mass') || "";
		my $amount = $_ -> get('Quantity') || "";
		my $st = $_ -> get('Start_Position');
		my $end = $_ -> get('End_Position');
		my $Verified_on_Gel = $_ -> get('Used_for_Protein_ID');
		if($Verified_on_Gel == 1){$Verified_on_Gel="Yes";}
		else{$Verified_on_Gel="No";}
		
		$Systematic_Name_for_Rollover = "";
		$Common_Name_for_Rollover = "";
		$Id_Method_for_Rollover = "";
		$Search_Engine_for_Rollover = "";
		$Protein_Id_for_Rollover = "";
		$MS_File_Suffix = "";
		
		my $ret;
		$sth->execute($Band_Id_for_Popup) or die "retrieve band error code: ", $DBI::errstr;
 		my $row_count = $sth->rows;
		my $cur_Protein_Id_for_Rollover;
		my @Protein_Id_for_Rollover_List=();
		if ($row_count > 0)
		{
			$ret = 1;
			while ( my @row = $sth->fetchrow_array )
			{
				($cur_Protein_Id_for_Rollover, $Search_Engine_for_Rollover, $Id_Method_for_Rollover, $MS_File_Suffix) = @row;
				push @Protein_Id_for_Rollover_List, $cur_Protein_Id_for_Rollover;
			}
			
			my $row_count=0;
			for my $cur_id (@Protein_Id_for_Rollover_List)
			{
				my $protein_db_entry = Biochemists_Dream::Protein_DB_Entry -> retrieve($cur_id);
				if ($row_count == 0)
				{
                    $Systematic_Name_for_Rollover .= $protein_db_entry -> get("Systematic_Name");
					$Common_Name_for_Rollover .= $protein_db_entry -> get("Common_Name");
                }
				else
				{
					$Systematic_Name_for_Rollover .= ("," . $protein_db_entry -> get("Systematic_Name"));
					$Common_Name_for_Rollover .= ("," . $protein_db_entry -> get("Common_Name"));
				}
				$row_count++;
			}
		}
		else
		{#if no proteins, this should come out as 0 from DB, but in that case we want by default the radio button to be set to Yes, so change it
			$ret = 0;
			$Verified_on_Gel="Yes";
		}
		
		my $show_current_data = 0; # 1 means show the data
		my $title;
		if($amount) { $title = "Mass: $mass kDa, Quantity: $amount $units"; }
		else { $title = "Mass: $mass kDa"; }
		
		if ($Common_Name_for_Rollover)
		{
	 		$title =  $title . ", Common Name: $Common_Name_for_Rollover";
			$show_current_data = 1;
		} else {$Common_Name_for_Rollover = " ";}
		if ($Id_Method_for_Rollover)
		{
			$title = $title . ", Id Method: $Id_Method_for_Rollover";
			$show_current_data = 1;
		} else {$Id_Method_for_Rollover = " ";}
		if ($Search_Engine_for_Rollover)
		{
	 		$title = $title . ", Search Engine: $Search_Engine_for_Rollover";
			$show_current_data = 1;
		} else {$Search_Engine_for_Rollover = " ";}
		if ($Protein_Id_for_Rollover)
		{
	 		#$title = $title . ", Protein Id: $Protein_Id_for_Rollover";
			$show_current_data = 1;
		} else {$Protein_Id_for_Rollover = 0;}
		
		if($Verified_on_Gel eq "No" and $ret)
		{#when it's set to No for verified, and protein id exists for band, put a *
			$title = $title . " *"
		}
		#this code creates a list based on whether a lane has protein data assigned to at least one band
		#if the sum is create then 0 will mean no bands and NOT 0 at least one band has been assigned a protein
		$has_band_been_assigned_protein += $show_current_data;
		
		my $experiment_dir = "/copurification/$user_id/Experiments";
		my $local_ms_fname = "gel$gel_num.lane.$lane_order.band.$Band_Id_for_Popup.ms";
		my $local_fname = "$experiment_dir/$exp_id/$local_ms_fname.$MS_File_Suffix";
		#my $Shared_Project = test_for_shared_project($exp_id, $g_user_id);

		#!to do! either set a min lane width and use a constant...or get the width of each image in pixels and use it here
		if($st && $end)
 		{#$Verified_on_Gel
			my $xml_file = 0;
			if ((lc $MS_File_Suffix) eq "xml") { $xml_file=1; }
            
			$ret_string .= qq!<area shape="rect" coords="0,$st,25,$end" href="#Add MS Protein to Band" !;
			$ret_string .= qq!onclick="show_popup_for_band('Add MS Protein to Band',$gel_num, \'$gel_name\', $lane_order, $Band_Id_for_Popup, $mass, $Protein_Id_for_Rollover, $show_current_data, &quot;$Id_Method_for_Rollover&quot;,&quot;$Search_Engine_for_Rollover&quot;, &quot;$Systematic_Name_for_Rollover&quot;, &quot;$Common_Name_for_Rollover&quot;, &quot;$local_fname&quot;, $Shared_Project,\'$Verified_on_Gel\',$xml_file)" title="$title" style="cursor:crosshair;" />!;
		}
	}
	
	$_[6] = $has_band_been_assigned_protein;
	param('switch_color', $has_band_been_assigned_protein);
	$ret_string .= qq!</map>!;

	$sth->finish();
	$dbh->disconnect();
			
	return $ret_string;
}

sub display_experiment_page
{
	my $id = shift;
	my $edit = shift;
	my $err_str = shift;
	my $exp = Biochemists_Dream::Experiment -> retrieve($id);
	my $project = $exp -> Project_Id;
	my $cur_user_id = $project -> get("User_Id");
	my $name = $exp -> get("Name");
	my $description = $exp -> get("Description");
	my $cur_species = $exp -> get("Species");
	my $proc_file = $exp -> get("Experiment_Procedure_File");
	my $gel_file = $exp -> get("Gel_Details_File");
	if (!$proc_file) { $proc_file = '(none selected)'; }
	if (!$gel_file) { $gel_file = '(none selected)'; }
	
	#print '<div id="dialog" class="popup_dialog"><p><img src="/cdi-html/spinner.gif"/> Submitting Experiment...  </p></div>';
	print hidden('experiment_id', $id);
	print hidden('current_species', $cur_species);
	if ($cur_user_id != $g_user_id)
	{
		print qq!<input type="hidden" id="shared_project" name="shared_project" value=1 />!;
    }
    
	if($edit) #$cur_user_id == $g_user_id && $edit) # John wants edit privileges to shared Exps
	{
		#get contents for species drop down box
		my @species = Biochemists_Dream::Species -> retrieve_all;
		my @species_names;
		foreach (@species) { push @species_names, $_ -> get('Name'); }

		#get contents for procedure drop down box
		#load all existing procedure and gel files for the user
		
		my @proc_files = get_files("$BASE_DIR/$DATA_DIR/$cur_user_id/Experiment_Procedures", '');
		unshift(@proc_files, '(none selected)');
		
		my @gel_files = get_files("$BASE_DIR/$DATA_DIR/$cur_user_id/Gel_Details", '');
		unshift(@gel_files, '(none selected)');

		print h2("Edit Experiment:"),
			  '<table><tr><td>',
			  'Name',
			  '</td><td>',
			  qq!<input type="text" name="experiment_name" value="$name" size="30" maxlength="30" />!,
			  '</td><tr><td>',
			  'Species',
			  '</td><td>',
			  popup_menu(-name=>'experiment_species', -values=>\@species_names, -default=>[$cur_species], -disabled=>'true'),
			  '</td><tr><td>',
			  'Description',
			  '</td><td>',
			  qq!<input type="text" name="experiment_description" value="$description" size="75" maxlength="150" />!,
			  '</td></tr>',
			  '<tr>',
			  '<td>Experimental Procedures File</td>',
			  '<td>',
			  popup_menu(-name=>'experiment_procedure', -values=>\@proc_files, -default=>[$proc_file]),
			  '</td></tr>',
			  '<tr>',
			  '<td>Gel Details File</td>',
			  '<td>',
			  popup_menu(-name=>'gel_details', -values=>\@gel_files, -default=>[$gel_file]),
			  '</td></tr>',
			  '</table>',
			  br(),
			  submit('submit', 'Save Changes'),
			  br(), br(),
			  submit('submit', 'Cancel'),
			  hidden('page_type', 'experiment');
	}
	else
	{
		print h2("Experiment '$name'"),
			  h3("Species: $cur_species"),
			  p("Description: $description");
		
		print qq!<p><a href="/copurification/$cur_user_id/Experiments/$id/data.txt" target='_blank'>Sample Descriptions File</a></p>!;
			  
		if ($proc_file eq '(none selected)')
		{ print "<p>Experimental Procedures File: $proc_file</p>"; }
		else { print qq!<p>Experimental Procedures File: <a href="/copurification/$cur_user_id/Experiment_Procedures/$proc_file" target="blank">$proc_file</a></p>!; }
		
		if ($gel_file eq '(none selected)')
		{ print "<p>Gel Details File: $gel_file</p>"; }
		else { print qq!<p>Gel Details File: <a href="/copurification/$cur_user_id/Gel_Details/$gel_file" target="blank">$gel_file</a></p>!; }
		
		if(1) #$cur_user_id == $g_user_id)
		{ print submit('submit', 'Edit'); }
		
		print hidden('page_type', 'experiment');
	}

	print hr();
	
	if (defined($err_str) && $err_str ne "") {
        print qq!<p style="color:red">$err_str</p>!;
    }
    

	display_experiment_results($id, $exp, '');

	display_footer();
}

sub get_files
{
	my $dir = shift;
	my $ext = shift;

	my @files_list;
	opendir(DIR, $dir);
	while (my $file = readdir(DIR))
	{
		# We only want files
		next unless (-f "$dir/$file");

		# Use a regular expression to find files ending in .txt
		if ($ext)
		{
			next unless ($file =~ m/\.$ext$/);
		}
		push @files_list, $file;
		#print "$file\n";
    }
    closedir(DIR);
    return @files_list;
}

sub display_experiment_results
{#displays the experiment results - table w/ gel, lanes and bands (masses) found
	#first, check if results are ready yet - check for 'DONE' at end of log file, also display any errors there
	my $exp_id = shift;
	my $exp_obj = shift;
	my $norm_img_str = shift;
	my $exp_user_id = $exp_obj -> Project_Id -> User_Id;
	my $exp_dir = "$BASE_DIR/$DATA_DIR/$exp_user_id/Experiments/$exp_id";
	my $results_ready = 0;
	my @errors;

	if(open(IN, "$exp_dir/$PROCESS_GELS_LOG_FILE_NAME"))
	{
		while(<IN>)
		{
			s/\r[\n]*/\n/gm;
			chomp();
			if($_ eq "DONE")
			{
				$results_ready = 1;
				last;
			}
			else { push @errors, $_, $_ eq "DONE"; }
		}
	}
	
	print qq!<div id="exp_results_table">!;
	if($results_ready)
	{
		if($#errors >= 0)
		{
			foreach (@errors) { print p($_); }
		}

		#get the gels for this experiment
		my @gels = $exp_obj->gels();

		#if all gels are public already, don't need 'Make Public' button
		my $need_button = 0;
		#Make Public button disabled -----
		#foreach (@gels) { if(!($_ -> get('Public'))) { $need_button = 1; } }

		
		print br();
		print '<table><tr><td>';
		if($need_button && $exp_user_id == $g_user_id) #-disabled=>'true'
		#{ print submit(-name=>'submit', -value=>'Make Public', -disabled=>'true'), '&nbsp;&nbsp;(selected gels)', '&nbsp;&nbsp;&nbsp;|&nbsp; '; }
		{ print submit(-name=>'submit', -value=>'Make Public'), '&nbsp;&nbsp;(selected gels)', '&nbsp;&nbsp;&nbsp;|&nbsp; '; }
		
		print qq!</td><td><a href="../copurification-cgi/copurification.pl?submit=LaneGrouping&experiment_id=$exp_id" target="top">View Lane Clustering</a>&nbsp;&nbsp;&nbsp;|&nbsp; !;
		print '</td><td><div id="slider" style="width:100px"></div></td></tr></table>';
		
		if (-e "$exp_dir/gel1-nnn.txt")
		{
            print '<script>$( "#slider" ).slider({ min: 0, max: 3 }); $( "#slider" ).on( "slidechange", function( event, ui ) { change_lanes(1); } ); </script>';
        }
		else
		{
			print '<script>$( "#slider" ).slider({ min: 0, max: 2 }); $( "#slider" ).on( "slidechange", function( event, ui ) { change_lanes(1); } ); </script>';
		}
        
		
		
		#print br();
		
		#display the gel data
		print qq!<input type="hidden" id="Gel_No_for_Popup" name="Gel_No_for_Popup" value="0">!;
		print qq!<input type="hidden" id="Gel_Id_for_Popup" name="Gel_Id_for_Popup" value="0">!;
		
		##
		print qq!<input type="hidden" id="Exp_Id_for_Popup" name="Exp_Id_for_Popup" value="$exp_id">!;	
		#print qq!<input type="hidden" id="Gel_No_for_Popup" name="Gel_No_for_Popup" value="$gel_num">!;
		#print qq!<input type="hidden" id="Gel_Id_for_Popup" name="Gel_Id_for_Popup" value="$gel_id">!;
		#print qq!<input type="hidden" id="Lane_Order_for_Popup" name="Lane_Order_for_Popup" value="">!; moved into subroutine was clearing out the data
		#print qq!<input type="hidden" id="Band_Id_for_Popup" name="Band_Id_for_Popup" value="">!;
		#print qq!<input type="hidden" id="Band_Id_for_File" name="Band_Id_for_File" value="">!;
		print qq!<input type="hidden" id="band_or_lane" name="band_or_lane" value="lane">!;
		print qq!<input type="hidden" id="update_or_delete" name="update_or_delete" value="">!;
		print qq!<input type="hidden" id="Protein_Id_for_Rollover" name="Protein_Id_for_Rollover" value="">!;
		
		print qq!<input type="hidden" id="Redisplay_Lane_Popup" name="Redisplay_Lane_Popup" value="No">!;
		print qq!<input type="hidden" id="Redisplay_Current_Lane_Data" name="Redisplay_Current_Lane_Data" value="No">!;
		print qq!<input type="hidden" id="Redisplay_Band_Popup" name="Redisplay_Band_Popup" value="No">!;
		print qq!<input type="hidden" id="Cur_Systematic_Name_For_Band" name="Cur_Systematic_Name_For_Band">!;
		print qq!<input type="hidden" id="Save_Lane_Order_for_Band_Processing" name="Save_Lane_Order_for_Band_Processing">!;
		##
	
		create_ms_search_engine_html ("");
		create_add_protein_to_band_html ();
		
		
	
		foreach my $gel (@gels)
		{
			print br();
			display_gel_details($gel, $exp_user_id, $norm_img_str);
		}
		
	}
	else
	{
		print p("Results pending, please check back later...");
		if($#errors >= 0)
		{
			print p("Error messages:");
			foreach (@errors) { print p($_); }
		}
	}
	print qq!</div>!;
	
}

sub display_project_tree
{
	my @projects = Biochemists_Dream::Project -> search(Project_Parent_Id => undef, User_Id => $g_user_id, {order_by => 'Name'});
	my @shared_projects = Biochemists_Dream::Shared_Projects -> search(User_Id => $g_user_id);
	
	print "<table>\n";
	#print out each (root) project, followed by the projects/experiments it contains (recursively)
	foreach my $cur_project (@projects)
	{
		display_project(0, $cur_project);
	}
	print "</table>\n";
	
	
	if (@shared_projects)
	{
		
		print h3("Shared Projects");
		print "<table>\n";
		#print out each (root) project, followed by the projects/experiments it contains (recursively)
		foreach my $cur_project (@shared_projects)
		{
			display_project(0, $cur_project->Project_Id);
		}
		print "</table>\n";
	}
	
	print "<hr>";
	print submit('submit', 'Delete');
	
	print "&nbsp;";
	print submit('submit', 'Search My Gels');
	
	#print "&nbsp;";
	#print submit('submit', 'Compare Gel Lanes');
}

sub display_project
{
	my $num_spaces = $_[0];
	my $project = $_[1];

	my $id = $project -> get("Id");
	my $user = $project -> get("User_Id");
	my $user_id = $user -> Id;
	my $name = $project -> get("Name");
	my $next_num_spaces = $num_spaces+3;

	#get sub projects:
	my @sub_projects = Biochemists_Dream::Project -> search(Project_Parent_Id => $id, {order_by => 'Name'});
	#get experiment listing
	my @experiments = Biochemists_Dream::Experiment -> search(Project_Id => $id, {order_by => 'Name'});

	# print out this project in a table row
	print "<tr><td>";

	#indent project
	my $n = $num_spaces; while($n) { print "&nbsp;"; $n--; }

	#then, print the +/- if there's subprojects or experiments, else space if the project is empty
	if($#sub_projects >= 0 || $#experiments >= 0)
	{ print qq!<img src="../copurification-html/plus.gif" onclick="expandcontract('table_$id', 'icon_$id')" id="icon_$id" style="cursor: pointer; cursor: hand;" title="Click to expand/contract" alt="+" />!; }
	else { print qq!<img src="../copurification-html/greyplus.gif" title="Empty project" alt="+" />!; }

	#then, the project name
	print qq!<input type="checkbox" name="project_checkbox" value="$id">!;
	#if ($user_id == $g_user_id)
	#{#if it's a shared project, current user is not the owner and we won't print out the check box
	#	print qq!<input type="checkbox" name="project_checkbox" value="$id">!;
	#}
	#else { print "&nbsp"; }
	
	print qq!<a href="../copurification-cgi/copurification.pl?submit=ViewProject;Id=$id" target="frame2">$name</a>!;
	if ($user_id != $g_user_id)
	{#if its shared project, print out the owner
		print "<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;(" . $user -> First_Name . " " . $user -> Last_Name . ")";
	}
	
	#end current project row
	print "</td></tr>\n";

	#if there is sub-projects and/or experiments, print them out, in a new table
	if($#sub_projects >= 0 || $#experiments >= 0)
	{
		print qq!<tr><td><table id="table_$id" style="display: none">!;

		#call this function (recursively) to print list of sub projects and thier children
		foreach my $sub_project (@sub_projects) { display_project($next_num_spaces, $sub_project); }

		#print out the experiments (they have no children!)
		foreach my $experiment (@experiments)
		{
			my $id = $experiment -> get("Id");
			my $name = $experiment -> get("Name");
			my $species_name = $experiment -> Species;
			my $n = $next_num_spaces;
			print "<tr><td>";
			while($n) { print "&nbsp;"; $n--; }
			print "&nbsp;&nbsp;&nbsp;"; #print filler image since no +/- for experiments
			print qq!<input type="checkbox" name="experiment_checkbox" value="$id">!;
			print qq!<a href="../copurification-cgi/copurification.pl?submit=ViewExperiment;Id=$id" target="frame2">$name</a>!;
			print "</td></tr>\n";
		}

		print "</table></td></tr>\n";
	}
}

sub display_add_project
{
	my $parent_name = shift;
	
	if ($parent_name) { print h2("Create New Project in '$parent_name'"); }
	else { print h2('Create New Project'); }
	
	print '<table><tr><td>',
		  'Name',
		  '</td><td>',
		  textfield('project_name', '', 30, 30),
		  '</td><tr><td>',
		  'Description',
		  '</td><td>',
		  textfield('project_description', '', 75, 150),
		  '</td></tr></table>',
		  submit('submit', 'Add Project');
}

sub display_add_experiment
{
	my $parent_name = shift;
	my $project_user_id = shift;
	
	#get the species choices from the species table of db
	my @species = Biochemists_Dream::Species -> retrieve_all;
	my @species_names;
	foreach (@species) { push @species_names, $_ -> get('Name'); }

	#load all existing procedure and gel files for the project owner
	my @proc_files = get_files("$BASE_DIR/$DATA_DIR/$project_user_id/Experiment_Procedures", '');
	unshift(@proc_files, '(none selected)');
	
	my @gel_files = get_files("$BASE_DIR/$DATA_DIR/$project_user_id/Gel_Details", '');

	unshift(@gel_files, '(none selected)');

	print hr(),
		  h2("Create New Experiment in '$parent_name'"),
		  '<table><tr>',
		  '<td>Name</td>',
		  '<td>',
		  textfield('experiment_name', '', 30, 30),
		  '</td>',
		  '</tr><tr>',
		  '<td>Species</td>',
		  '<td>',
		  popup_menu(-name=>'experiment_species', -values=>\@species_names),
		  '</td>',
		  '</tr><tr>',
		  '<td>Description</td>',
		  '<td>',
		  textfield('experiment_description', '', 75, 150),
		  '</td>',
		  '</tr><tr>',
		  '<td nowrap>Experimental Procedures File </td>',
		  '<td>',
		  popup_menu(-name=>'experiment_procedure', -values=>\@proc_files ), #, -labels=>\%proc_labels),
		  '</td>',
		  '</tr><tr>',
		  '<td>Gel Details File</td>',
		  '<td>',
		  popup_menu(-name=>'gel_details', -values=>\@gel_files ), #, -labels=>\%proc_labels),
		  '</td>',
		  '</tr><tr>',
		  '<td>Sample Descriptions file</td>',
		  '<td>',
		  filefield('experiment_data_file'),
		  #'&nbsp;&nbsp;', 
		  a({href=>"../copurification-html/HowTo.html#SD", target=>'_blank'}, "HOWTO create this file"), 
		  '</td>',
		 '</tr><tr>',
		 '<td>Gel file(s)</td>',
		 '<td style="white-space: nowrap">',
		 '<input name="gel_data_file" type="file" class="multi" accept="tif|png|bmp|jpg"/>',
		  '</td></tr></table>';

		  print submit('submit', 'Add Experiment'); 
}

sub display_footer
{
	#my $lic = shift;
	#if ($lic)
	#{
	#	print qq!<hr><p style="text-align:center;"><a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/3.0/deed.en_US">!,
	#	qq!<img alt="Creative Commons License" style="border-width:0" src="http://i.creativecommons.org/l/by-nc-sa/3.0/88x31.png" /></a>!,
	#	qq!<br><br>This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/3.0/deed.en_US">!,
	#	qq!Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License</a>.</p>!;
	#}
	
	
	print end_multipart_form();
#	print <<GOOGLEANAL;
#	<script>
#		(function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
#		(i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
#		m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
#		})(window,document,'script','//www.google-analytics.com/analytics.js','ga');
#	      
#		ga('create', 'UA-62498626-1', 'auto');
#		ga('send', 'pageview');
#	</script>
#GOOGLEANAL
	print end_html();
}

#uploads a file to the server, given (1) remote file name, (2) file handle to the file to upload, and
#(3) local file name root (the appropriate extension will be added)
sub upload_file
{
	my $user_fname = $_[0];
	my $fh = $_[1];
	my $local_fname_root = $_[2];

	my $extension = $user_fname;
	if ($extension =~ s/^.*\.([^\.]+)$/$1/)
	{
		my $line;
		$extension = lc $extension;
		if(open (OUTFILE, ">$local_fname_root.$extension"))
		{
			#save the file, create the local name using the extension of the user file
			if ($user_fname =~ /\.txt$/i)
			{
				while ( $line=<$fh> )
				{
					chomp($line);
					$line=~s/\r$//;
					$line=~s/\r([^\n])/\n$1/g;
					print OUTFILE "$line\n";
				}
			}
			else
			{
				binmode OUTFILE;
				my $buffer;
				while (read($fh,$buffer,1024) )
				{
				    print OUTFILE $buffer;
				}
				#while ($line=<$fh>)
				#{
				#	print OUTFILE $line;
				#}
			}
			close(OUTFILE);
		}
		else { return  "Could not open local file to save $user_fname"; }
	}
	else { return "Could not extract extension from $user_fname"; }

	$_[3] = $extension;
	return "";
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

sub get_experiments_in_project
{#returns a list of all experiments that are in this project and all subprojects
 #arg 1: project id, arg2: ref to array of ids (sub will fill this in)
	my $project_id = shift;
	my $exp_list_ref = shift; # @$exp_list_ref is the array

	#get the experiments in this project
	my @experiments = Biochemists_Dream::Experiment -> search( Project_Id => $project_id );
	foreach my $exp (@experiments) { push @$exp_list_ref, $exp; }

	#get a list of the subprojects and get the experiments for those projects (recursively)
	my @sub_projects = Biochemists_Dream::Project -> search( Project_Parent_Id => $project_id );
	foreach my $sub_project (@sub_projects) { get_experiments_in_project($sub_project->get("Id"), $exp_list_ref); }
}

sub delete_project
{
	my $id = shift;

	my $project = Biochemists_Dream::Project -> retrieve( $id );
	if ($project -> User_Id -> Id != $g_user_id)
	{
		return "Can't delete Project '" . $project -> Name . "': it is owned by another user.<br>";
	}

	#get all experiments in this project (and any subprojects) so that the directories can be deleted
	my @experiments_deleted;
	get_experiments_in_project($id, \@experiments_deleted);

	#delete all experiment directories
	my $err_str = "";
	foreach my $exp (@experiments_deleted)
	{
		my $exp_id = $exp -> get("Id");
		my $experiment_dir = "$BASE_DIR/$DATA_DIR/$g_user_id/Experiments/$exp_id";

		$err_str .= delete_directory($experiment_dir);
	}

	#delete the project (all experiments deleted by cascading delete)
	$project -> delete();

	return $err_str;
}

sub delete_experiment
{
	my $id = shift;

	my $exp = Biochemists_Dream::Experiment -> retrieve( $id );
	if ($exp -> Project_Id -> User_Id != $g_user_id)
	{
		return "Can't delete Experiment '" . $exp -> Name . "': it is owned by another user.<br>";
	}
	
	$exp -> delete();

	# delete, also, all files and the associated directory of this experiment
	my $experiment_dir = "$BASE_DIR/$DATA_DIR/$g_user_id/Experiments/$id";

	my $err_str = delete_directory($experiment_dir);

	return $err_str;
}

sub logout_the_user
{
	$g_the_user = undef;
}
sub login_the_user
{
	$g_the_user = Biochemists_Dream::User -> retrieve($g_user_id);
	if(!$g_the_user) { return 0; }
	else { return 1; }
}

sub validate_user
{
	my $email = shift;
	my $password = shift;

	my @users = Biochemists_Dream::User -> search(Email => $email);
	if($#users < 0)
	{ #email not found in db
		if($DEVELOPER_VERSION) { print DEVEL_OUT "User email not found: $email\n"; }
		return 0;
	}

	my $user = $users[0]; #email is unique key so should be only 1 user

	my $valid_password_crypt = $user -> get('password');
	my $user_id = $user -> get('Id');
	if(crypt($password, $valid_password_crypt) ne $valid_password_crypt)
	{ #wrong password!
		if($DEVELOPER_VERSION) { print DEVEL_OUT "Password mismatch for user $email\n"; }
		return 0;
		#return $user_id;
	}
	else
	{#login success!
		if($DEVELOPER_VERSION) { print DEVEL_OUT "Login success for user $email\n"; }
		return $user_id;
	}
}

sub print_javascript
{
	my $more_js = shift;

	print qq!<SCRIPT LANGUAGE="JavaScript">\n\n!;
	if($more_js) { print "$more_js\n\n"; }
	print <<JSCRIPT;
	
	function check_show_results(log_file_url)
	{
		\$( '#new_exp_result' ).load(log_file_url);
		parent.frame1.location.reload('../copurification-cgi/copurification.pl?frame=1');
	}

	// Row Hide function.
	function expandcontract(tId, clickIcon)
	{
		dstyle = document.getElementById(tId).style.display;
		if (dstyle == "none")
		{
			document.getElementById(tId).style.display = "";
			document.getElementById(clickIcon).src = "../copurification-html/minus.gif";
			document.getElementById(clickIcon).alt = "-";
		}
		else
		{
			document.getElementById(tId).style.display = "none";
			document.getElementById(clickIcon).src = "../copurification-html/plus.gif";
			document.getElementById(clickIcon).alt = "+";
		}
	}

	//Open in new window, not new tab...
	function pop_up(hyperlink, window_name)
	{
		if (! window.focus)
			return true;
		var href;
		if (typeof(hyperlink) == 'string')
			href=hyperlink;
		else
			href=hyperlink.href;
		window.open(
			href,
			window_name,
			'width=800,height=800,toolbar=no, scrollbars=yes'
		);
		return false;
	}
	function validateNumber(evt)
	{
		var e = evt || window.event;
		var key = e.keyCode || e.which;
	    
		if (!e.shiftKey && !e.altKey && !e.ctrlKey &&
		// numbers   
		key >= 48 && key <= 57 ||
		// Numeric keypad
		key >= 96 && key <= 105 ||
		// Backspace and Tab and Enter
		key == 8 || key == 9 || key == 13 ||
		// Home and End
		key == 35 || key == 36 ||
		// left and right arrows
		key == 37 || key == 39 ||
		// Del and Ins
		key == 46 || key == 45 ||
		// period and . on keypad
		key == 190 || key == 110)
		{
		    // input is VALID
		}
		else
		{
		    // input is INVALID
		    e.returnValue = false;
		    if (e.preventDefault) e.preventDefault();
		}
	}
	function filter_lanes()
	{
		check_arr = document.getElementsByName('check_lanes');
		for(i = 0; i < check_arr.length; i++)
		{
			check_value = check_arr[i].value;
			hidden_field = document.getElementById(check_value);
			if(!check_arr[i].checked)
			{
				
				
				lane_id = 'l_' + check_value;
				table_cols = document.getElementsByName(lane_id);
				for(j = 0; j < table_cols.length; j++)
				{
					table_cols[j].style.display = "none";
				}
				
				
				hidden_field.value = 'off';
			}
			else
			{
				hidden_field.value = 'on';
			}
		}
	}
	function lanes_report(arg1, arg2, arg3, arg4)
	{
		check_arr = document.getElementsByName('check_lanes');
		submit_string = "submit=LanesReport;IdList=";
		var first = 1;
		for(i = 0; i < check_arr.length; i++)
		{
			hidden_field = document.getElementById(check_arr[i].value);
			if(hidden_field.value == 'on')
			{
				if(first) { submit_string += check_arr[i].value; }
				else { submit_string += ("," + check_arr[i].value); }
				first = 0;
			}	
		}
		window.open("./copurification.pl?" + submit_string + ";protein=" + arg1 + ";species=" + arg2 + ";type=" + arg3 + ";systematic_name=" + arg4)
		
	}
	function change_lanes(remove_rects)
	{
		//need to remove any rects (from adding manual bands) b/c size of lane imgs may change therefore rect will become unaligned
		if(remove_rects)
		{
			\$(".rect").remove();
		}
		
		var value = \$( "#slider" ).slider( "option", "value" );
		
		if(value == 0)
		{
			arr = document.getElementsByName('lane_image'); 
			for(i = 0; i < arr.length; i++)
			{
				arr[i].style.display = "";
				lane_img_n='';
			}
			
			var arr = document.getElementsByName('norm_lane_image');
			for(i = 0; i < arr.length; i++)
			{
				arr[i].style.display = "none";
			}
			
			var arr = document.getElementsByName('norm_lane_image2');
			for(i = 0; i < arr.length; i++)
			{
				arr[i].style.display = "none";
			}
			
			var arr = document.getElementsByName('norm_lane_image3');
			for(i = 0; i < arr.length; i++)
			{
				arr[i].style.display = "none";
			}
			
		}
		else if(value == 1)
		{
			var arr = document.getElementsByName('norm_lane_image');
			for(i = 0; i < arr.length; i++)
			{
				arr[i].style.display = "";
				lane_img_n='-n';
			}
			
			var arr = document.getElementsByName('norm_lane_image2');
			for(i = 0; i < arr.length; i++)
			{
				arr[i].style.display = "none";
			}
			
			var arr = document.getElementsByName('norm_lane_image3');
			for(i = 0; i < arr.length; i++)
			{
				arr[i].style.display = "none";
			}
			
			arr = document.getElementsByName('lane_image'); 
			for(i = 0; i < arr.length; i++)
			{
				arr[i].style.display = "none";
			}
		}
		else if(value == 2)
		{
			var arr = document.getElementsByName('norm_lane_image2');
			for(i = 0; i < arr.length; i++)
			{
				arr[i].style.display = "";
				lane_img_n='-nn';
			}
			
			var arr = document.getElementsByName('norm_lane_image3');
			for(i = 0; i < arr.length; i++)
			{
				arr[i].style.display = "none";
			}
			
			var arr = document.getElementsByName('norm_lane_image');
			for(i = 0; i < arr.length; i++)
			{
				arr[i].style.display = "none";
			}
			
			arr = document.getElementsByName('lane_image'); 
			for(i = 0; i < arr.length; i++)
			{
				arr[i].style.display = "none";
			}
		}
		else
		{
			var arr = document.getElementsByName('norm_lane_image3');
			for(i = 0; i < arr.length; i++)
			{
				arr[i].style.display = "";
				lane_img_n='-nnn';
			}
			
			var arr = document.getElementsByName('norm_lane_image2');
			for(i = 0; i < arr.length; i++)
			{
				arr[i].style.display = "none";
			}
			
			var arr = document.getElementsByName('norm_lane_image');
			for(i = 0; i < arr.length; i++)
			{
				arr[i].style.display = "none";
			}
			
			arr = document.getElementsByName('lane_image'); 
			for(i = 0; i < arr.length; i++)
			{
				arr[i].style.display = "none";
			}
			
		}
	}
	function checkFileReplace(subDir)
	{
		var new_file = document.getElementById(subDir).value;
		var file_list = document.getElementsByName(subDir + "-list");
		var match = false;
		
		for (var i=0;i<file_list.length;i++)
		{
			if(file_list[i].value.toLowerCase() == new_file.toLowerCase())
			{
				match = true;
				break;
			}
		}
		if(match)
		{
			//warn user, get OK or Cancel
			var r=confirm("This file already exists.  If you upload a new version, the old file will be overwritten.  Do you want to proceed?");
			if (r==true)
			{
				document.getElementById('main_form').submit();
			}
		}
		else
		{
			//proceed with submit
			document.getElementById('main_form').submit();
		}
	}
	var ctr=0;
	function openWin(text)
	{
			var winName = "win_"+(ctr++);
			winpops=window.open("",winName,"width=400,height=600")
			winpops.document.write("<p>" + text + "</p>");
	}
	
	function show_popup_for_lane (id,Gel_Id,Gel_Num,Display_Name,Lane_Order,Show_Current_Data,MS_Search_Engine,Mass_Spect_File,Shared_Project,xml_file)
	
	{
		hide_popup_for_lane ('Add MS Database to Lane');  // force the close button in case of lane jumping
		hide_popup_for_band ('Add MS Protein to Band');
		document.getElementById('error_message_for_lane_popup').style.display="";  // need to reset in case someone switches lanes
		
		document.getElementById('Gel_Id_for_Display').innerHTML = Display_Name;
		document.getElementById('LaneOrder').innerHTML = Lane_Order;
		
		document.getElementById('Lane_Order_for_Popup').value = Lane_Order; //this sends data back for updating DB
		document.getElementById('Gel_Id_for_Popup').value = Gel_Id;
		document.getElementById('Gel_No_for_Popup').value = Gel_Num;
		document.getElementById('Xtandem').selected = "true";
		document.getElementById('mass_spect_file').value = "";
		document.getElementById('mass_spect_file').required = ""; //cannot make required must handle in code
		//never turn on input panel when viewing experiment belonging to someone else
		//if (Shared_Project == 1) {
		//	document.getElementById('Lane Popup Header').style.display="none";
		//	document.getElementById('Lane Input Panel').style.display="none";
		//}
		
		if (Show_Current_Data == 1) {
			document.getElementById('cur_ms_search_engine').innerHTML = MS_Search_Engine;
			document.getElementById('cur_local_ms_file').href = Mass_Spect_File;
			if(xml_file == 1)
			{
				document.getElementById('cur_local_ms_file').download = "xml_file";
			}
			document.getElementById('Display Existing Lane Info').style.display="";
			document.getElementById('delMassSpectButton').style.display="";
  			document.getElementById('Lane Popup Header').style.display="";
			document.getElementById('ms_search_engine').value=MS_Search_Engine;
  			//document.getElementById('info_message_for_lane_file').style.display="";
		} else {
			document.getElementById('cur_ms_search_engine').innerHTML = " ";
			document.getElementById('cur_local_ms_file').href = " ";
			document.getElementById('Display Existing Lane Info').style.display="none";
			document.getElementById('delMassSpectButton').style.display="none";
			//document.getElementById('info_message_for_lane_file').style.display="none"; 
		}
		
		document.getElementById('band_or_lane').value = 'lane';
		
		document.getElementById(id).style.display="";
	}

	function hide_popup_for_lane (id)
	{
		document.getElementById('ms_search_engine').required = "";
		document.getElementById('mass_spect_file').required = "";
		document.getElementById('error_message_for_lane_popup').innerHTML = " ";
		
		document.getElementById(id).style.display="none";
	}

	function update_lane_color_for_band (id,Switch_Color)
	{
		if (Switch_Color != 0) {document.getElementById(id).style.color="orange"};
	}
	
	function show_popup_for_band (id,GelNum,GelName,Lane_Order,Band_Id,Band_Mass,Protein_Id,Show_Current_Data,Id_Method_for_Rollover,Search_Engine_for_Rollover,Systematic_Name_for_Rollover,Common_Name_for_Rollover,Mass_Spect_File,Shared_Project,Verified_On_Gel,xml_file)
	{
		hide_popup_for_lane ('Add MS Database to Lane');
		
		document.getElementById('ms_protein_id_method').value = 'mass spec';
		document.getElementById('ms_search_engine_for_band').selected = 'Xtandem';
		document.getElementById('Xtandem').selected = "true";
		display_updates_for_band(); // this inits and fixes problems of bad display when clicking to different band for input
		document.getElementById('error_message_for_band_popup').innerHTML = " ";  // need to reset in case someone switches bands

		//these elements populate the header for the popup	
		document.getElementById('GelIdforBand').innerHTML = GelName;
		document.getElementById('LaneOrderforBand').innerHTML = Lane_Order;
		document.getElementById('Band_Mass_for_Display').innerHTML = Band_Mass;
		
		document.getElementById('Gel_No_for_Popup').value = GelNum;
		
		//
		document.getElementById('Lane_Order_for_Popup').value = Lane_Order; //this sends data back for updating DB
		document.getElementById('Band_Id_for_Popup').value = Band_Id; //this sends data back for updating DB
		document.getElementById('Band_Id_for_File').value = Band_Id; //this sends data back for updating DB
		document.getElementById('Band_Mass_for_Popup').value = Band_Mass;
		document.getElementById('Protein_Id_for_Rollover').value = Protein_Id; //this sends data back for updating DB
		document.getElementById('ms_protein_name').value = "";
		document.getElementById('ms_protein_name').required = ""; // cannot make required because of delete button - handle in code
		document.getElementById('mass spec').selected = "true";
		document.getElementById('Cur_Systematic_Name_For_Band').value = Common_Name_for_Rollover;
		
		//never turn on input panel when viewing experiment belonging to someone else
		//if (Shared_Project == 1) {
		//	document.getElementById('Band Popup Header').style.display="none";
		//	document.getElementById('Band Input Panel').style.display="none";
		//}
		
		if (Show_Current_Data == 1)
		{
			document.getElementById('cur_band_protein').innerHTML = Common_Name_for_Rollover;
			document.getElementById('cur_protein_id_method').innerHTML = Id_Method_for_Rollover;
			
			document.getElementById('delMassSpectButton2').style.display="";
			if (Id_Method_for_Rollover == "mass spec")
			{
				document.getElementById('cur_ms_search_engine_for_band').innerHTML = Search_Engine_for_Rollover;
				document.getElementById('cur ms spect engine display for band').style.display = "";
				document.getElementById('cur_local_ms_file_for_band').href = Mass_Spect_File;
				if(xml_file == 1)
				{
					document.getElementById('cur_local_ms_file_for_band').download = "xml_file";
				}
				document.getElementById('cur ms spect file display for band').style.display = "";
			}
			else
			{
				document.getElementById('cur ms spect engine display for band').style.display = "none";
				document.getElementById('cur ms spect file display for band').style.display = "none";
			}
			document.getElementById('Band Popup Header').style.display="";
			document.getElementById('Display Existing Band Info').style.display="";
			
			document.getElementById('ms_protein_name').value = Systematic_Name_for_Rollover;
			document.getElementById('ms_protein_id_method').value = Id_Method_for_Rollover;
			if(Verified_On_Gel=="No")
			{
				document.getElementById('cur_verified_on_this_gel').innerHTML="No";
				document.getElementById('verified_on_this_gel_no').checked = true;
			}
			else
			{
				document.getElementById('cur_verified_on_this_gel').innerHTML="Yes";
				document.getElementById('verified_on_this_gel_yes').checked = true;
			}
			if (Id_Method_for_Rollover == "mass spec") 
			{
				document.getElementById('ms_search_engine_for_band').value = Search_Engine_for_Rollover;
				//document.getElementById('ms_search_engine_for_band').style.display = "";
				//document.getElementById('mass_spect_file_for_band').style.display = "";
				//document.getElementById('info_message_for_band_file').style.display = "";
				
				document.getElementById('ms spect engine display for band').style.display="";
				document.getElementById('ms spect file display for band').style.display="";
				document.getElementById('ms spect file display for band').required = "true";
			}
			else
			{
				document.getElementById('ms_search_engine_for_band').value = "Xtandem";
				//document.getElementById('ms_search_engine_for_band').style.display = "none";
				//document.getElementById('mass_spect_file_for_band').style.display = "none";
				//document.getElementById('info_message_for_band_file').style.display = "none";
				
				document.getElementById('ms spect engine display for band').style.display="none";
				document.getElementById('ms spect file display for band').style.display="none";			
				document.getElementById('ms spect file display for band').required = "";
								

			}
		}
		else
		{
			document.getElementById('cur_band_protein').innerHTML = " ";
			document.getElementById('cur_protein_id_method').innerHTML = " ";
			document.getElementById('cur_ms_search_engine_for_band').innerHTML = " ";
			document.getElementById('cur_local_ms_file_for_band').href = " ";
			document.getElementById('Display Existing Band Info').style.display="none";
			document.getElementById('delMassSpectButton2').style.display="none";
			
			document.getElementById('ms_protein_name').value = "";
			document.getElementById('ms_protein_id_method').value = "mass spec";
			document.getElementById('ms_search_engine_for_band').value = "Xtandem";
			document.getElementById('verified_on_this_gel_yes').checked = true;
			document.getElementById('verified_on_this_gel_no').checked = false;
		}
		document.getElementById('band_or_lane').value = 'band';
		document.getElementById(id).style.display="";
	}

	function hide_popup_for_band (id)
	{
		//must turn off required attribute for band pop up - must remember to turn back on for band pop up
		document.getElementById('ms_protein_name').required = "";
		document.getElementById('ms_protein_id_method').required = "";
		document.getElementById('error_message_for_band_popup').innerHTML = " ";

		document.getElementById(id).style.display="none";
		document.getElementById('Display Existing Band Info').style.display="none";
		document.getElementById('ms spect engine display for band').style.display="none";
		document.getElementById('ms spect file display for band').style.display="none";			
	}
	function display_updates_for_band()
	{
		if (document.getElementById('ms_protein_id_method').value == 'mass spec')
		{
			document.getElementById('ms spect engine display for band').style.display="";
			document.getElementById('ms spect file display for band').style.display="";
			document.getElementById('ms spect file display for band').required = "true";
		} else {
			document.getElementById('ms spect engine display for band').style.display="none";
			document.getElementById('ms spect file display for band').style.display="none";			
			document.getElementById('ms spect file display for band').required = "";
		}
	}
	
	function addMassSpectData(type,update_or_delete)
	{
		document.getElementById('band_or_lane').value = type;
		document.getElementById('update_or_delete').value = update_or_delete;
		//document.getElementByName('action').value = "Save MS Data";
		//checkAndSubmit();
	}
	</SCRIPT>

JSCRIPT
}

sub display_query_results
{#input - an array ref to an array of lane ids to display
 #and, a hash ref to a hash of conditions to display
	my $mode = shift;
	
	my $protein = shift;
	my $species = shift;
	my $sys_ID = shift;

	my $lane_ids_ref = shift;
	my $reagents_ref = shift;
	my $img_tags_ref = shift;
	my $image_map_str = shift; #print this, it is the imagemap of the lane masses...
	my $ph_ref = shift;

	my $experiments_ref; my $projects_ref;
	my $users_ref; my $species_ref;
	if($mode eq 'PRIVATE')
	{
		$experiments_ref = shift;
		$projects_ref = shift;
		display_title_header('');
	}
	else
	{
		$users_ref = shift;
		display_title_header('');
	}
	
	my $exp_proc_files_ref = shift;
	my $gel_details_files_ref = shift;
	my $checks_tags_ref = shift;
	my $hidden_fields = shift;
	my $over_exp_ref = shift;
	my $tag_type_ref = shift;
	my $tag_loc_ref = shift;
	my $antibody_ref = shift;
	my $other_cap_ref = shift;
	my $notes_ref = shift;
	#added for SRF update
	my $srf_ref = shift;
	my $elution_method_ref=shift;
	my $elution_reagent_ref=shift;
	my $citations_ref=shift;
	my $xrefs_ref=shift;
	my $lane_ms_ref=shift;
	my $max_over = shift; #if this is true display a message that we are only dipslay up to max number of display lanes 
	#print start_multipart_form();
	print qq!<h3>Results for $protein ($species) [ID: $sys_ID] &nbsp;&nbsp;&nbsp;!;
	print qq!<input type="button" value="Create Report (pdf)" onclick="lanes_report('$protein', '$species', '$mode', '$sys_ID')"></h3>!;
	
	my @lane_ids_arr = @{$lane_ids_ref};

	if($#lane_ids_arr < 0) { print p("No lanes matched your query."); }
	else
	{
		my $cur_lane_id;
		
		print $image_map_str;
		if($max_over) { print p("The first $MAX_DISPLAY_LANES lanes are displayed."); }
		print "<table rules=all>";
		
		#print out check box selections for each lane
		print "<tr>";
		print "<td><input type='button' value='Filter Lanes' onclick='filter_lanes()'/></td>";
		$cur_lane_id = 0;
		foreach (@{$checks_tags_ref})
		{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
		print "</tr>";
		
		#display lane image for each lane
		print "<tr>";
		print '<td><b>Lane Image</b><br><br>';
		print '<div id="slider" style="width:100px"></div>';
		print '<script>$( "#slider" ).slider({ min: 0, max: 3 }); $( "#slider" ).on( "slidechange", function( event, ui ) { change_lanes(0); } ); </script>';
		print "</td>";
		$cur_lane_id = 0;
		foreach (@{$img_tags_ref})
		{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
		print "</tr>";
		
		print "<tr>";
		print "<td><b>Lane MS</b></td>";
		$cur_lane_id = 0;
		foreach (@{$lane_ms_ref})
		{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
		print "</tr>";
		
		#print out, by column, the conditions for each lane
		my @reagent_types = Biochemists_Dream::Reagent_Types -> retrieve_from_sql(qq{ Display_Order > 0 ORDER BY Display_Order});
		#my @reagent_types = Biochemists_Dream::Reagent_Types -> retrieve_all;
		foreach (@reagent_types)
		{
			print "<tr>";
			my $name = $_ -> get("Name"); #<div name="l_$lane_id"></div>
			print "<td><b>$name</b></td>";

			foreach my $lane_id (@{$lane_ids_ref})
			{
				#print "<td>$lane_id</td>";
				if(defined ${$reagents_ref}{$lane_id}{$name}) { print "<td name='l_$lane_id'>${$reagents_ref}{$lane_id}{$name}</td>"; }
				else { print "<td name='l_$lane_id'>&nbsp;</td>"; }
				
			}
			print "</tr>";
		}
		
		#ph
		print "<tr>";
		print "<td><b>pH</b></td>";
		$cur_lane_id = 0;
		foreach (@{$ph_ref})
		{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
		print "</tr>";
		
		#over-expressed
		print "<tr>";
		print "<td><b>Over Expressed?</b></td>";
		$cur_lane_id = 0;
		foreach (@{$over_exp_ref})
		{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
		print "</tr>";
		
		#tag type
		print "<tr>";
		print "<td><b>Tag Type</b></td>";
		$cur_lane_id = 0;
		foreach (@{$tag_type_ref})
		{
			if (length($_) > $MAX_QUERY_RESULTS_FIELD_LENGTH)
			{
				my $min_str = substr($_, 0, 30);
				print qq!<td name="l_$lane_ids_arr[$cur_lane_id]">$min_str...<img title="Click to view Tag Type" src="../copurification-html/open_popup.png" onclick="openWin('$_')"/></td>!;
			}
			else { print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>";  }
			$cur_lane_id++;
		}
		#foreach (@{$tag_type_ref})
		#{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
		print "</tr>";
		
		#tag location
		print "<tr>";
		print "<td><b>Tag Location</b></td>";
		$cur_lane_id = 0;
		foreach (@{$tag_loc_ref})
		{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
		print "</tr>";
		
		#antibody
		print "<tr>";
		print "<td><b>Antibody</b></td>";
		$cur_lane_id = 0;
		foreach (@{$antibody_ref})
		{
			if (length($_) > $MAX_QUERY_RESULTS_FIELD_LENGTH)
			{
				my $min_str = substr($_, 0, 30);
				print qq!<td name="l_$lane_ids_arr[$cur_lane_id]">$min_str...<img title="Click to view Antibody" src="../copurification-html/open_popup.png" onclick="openWin('$_')"/></td>!;
			}
			else { print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>";  }
			$cur_lane_id++;
		}
		#foreach (@{$antibody_ref})
		#{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
		print "</tr>";
		
		#other capture
		print "<tr>";
		print "<td><b>Other Capture</b></td>";
		$cur_lane_id = 0;
		foreach (@{$other_cap_ref})
		{
			if (length($_) > $MAX_QUERY_RESULTS_FIELD_LENGTH)
			{
				my $min_str = substr($_, 0, 30);
				print qq!<td name="l_$lane_ids_arr[$cur_lane_id]">$min_str...<img title="Click to view Other Capture" src="../copurification-html/open_popup.png" onclick="openWin('$_')"/></td>!;
			}
			else { print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>";  }
			$cur_lane_id++;
		}
		
		#foreach (@{$other_cap_ref})
		#{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
		print "</tr>";
		
		#notes
		print "<tr>";
		print "<td><b>Notes</b></td>";
		$cur_lane_id = 0;
		foreach (@{$notes_ref})
		{
			if (length($_) > $MAX_QUERY_RESULTS_FIELD_LENGTH)
			{
				my $min_str = substr($_, 0, 30);
				print qq!<td name="l_$lane_ids_arr[$cur_lane_id]">$min_str...<img title="Click to view Notes" src="../copurification-html/open_popup.png" onclick="openWin('$_')"/></td>!;
			}
			else { print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>";  }
			$cur_lane_id++;
		}
		print "</tr>";
		
		### need to figure out how to populate the array
				
		#Single Reagent Flag
		print "<tr>";
		print "<td><b>Single Reagent Flag</b></td>";
		$cur_lane_id = 0;
		foreach (@{$srf_ref})
		{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
		print "</tr>";
		
		#Elution method
		print "<tr>";
		print "<td><b>Elution method</b></td>";
		$cur_lane_id = 0;
		foreach (@{$elution_method_ref})
		{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
		print "</tr>";
		
		#Elution reagent
		print "<tr>";
		print "<td><b>Elution reagent</b></td>";
		$cur_lane_id = 0;
		foreach (@{$elution_reagent_ref})
		{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
		print "</tr>";

		#Experiment Procedures File link
		print "<tr>";
		print "<td><b>Experimental Procedures</b></td>";
		$cur_lane_id = 0;
		foreach (@{$exp_proc_files_ref})
		{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
		print "</tr>";
		
		#Gel Details File link
		print "<tr>";
		print "<td><b>Gel Details</b></td>";
		$cur_lane_id = 0;
		foreach (@{$gel_details_files_ref})
		{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
		print "</tr>";

		if($mode eq 'PRIVATE')
		{
			#print out the experiment for each lane
			print "<tr>";
			print "<td><b>Experiment</b></td>";
			$cur_lane_id = 0;
			foreach (@{$experiments_ref})
			{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
			print "</tr>";

			#print out the project for each lane
			print "<tr>";
			print "<td><b>Project</b></td>";
			$cur_lane_id = 0;
			foreach (@{$projects_ref})
			{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
			print "</tr>";
		}
		else
		{
			#print out the user for each lane
			print "<tr>";
			print "<td><b>Submitter</b></td>";
			$cur_lane_id = 0;
			foreach (@{$users_ref})
			{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
			print "</tr>";
		}
		
		#print out the citation for each lane
		print "<tr>";
		print "<td><b>Citation</b></td>";
		$cur_lane_id = 0;
		foreach (@{$citations_ref})
		{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
		print "</tr>";
		
		#print out the citation for each lane
		print "<tr>";
		print "<td><b>XRef</b></td>";
		$cur_lane_id = 0;
		foreach (@{$xrefs_ref})
		{ print "<td name='l_$lane_ids_arr[$cur_lane_id]'>$_</td>"; $cur_lane_id++; }
		print "</tr>";
		
		#print hidden field for report generation
		print $hidden_fields;

		print "</table>";

	}

	display_footer();
}

sub save_query_results
{
	#create html file
	my $fname = "$BASE_DIR/$DATA_DIR/Reports/" . time() . "_" . rand() . ".htm";
	open(HTM_OUT, ">", "$fname");
	
	my $mode = shift;
	
	my $protein = shift;
	my $species = shift;
	my $sys_ID = shift;

	my $lane_ids_ref = shift;
	my $reagents_ref = shift;
	my $img_tags_ref = shift;
	my $ph_ref = shift;
	
	my $users_ref; my $experiments_ref; my $projects_ref;
	if($mode eq 'PRIVATE')
	{
		$experiments_ref = shift;
		$projects_ref = shift;
	}
	else
	{
		$users_ref = shift;
	}
	
	my $exp_proc_files_ref = shift;
	my $gel_details_files_ref = shift;
	my $over_exp_ref = shift;
	my $tag_type_ref = shift;
	my $tag_loc_ref = shift;
	my $antibody_ref = shift;
	my $other_cap_ref = shift;
	my $notes_ref = shift;
	my $single_reagent_flag_ref = shift;
	my $elution_method_ref = shift;
	my $elution_reagent_ref = shift;
	my $page_number = shift;
	
	print HTM_OUT <<START_HTML;	
<html lang="en">
<head>
<meta charset="utf-8">
<title>copurification.org</title>
<link rel="stylesheet" href="../../html/main2.css">
</head>
<body > <!-- style="background-color:white;"  -->
START_HTML

	print HTM_OUT "<a href='http://www.copurification.org' target='_blank' >www.copurification.org</a><br><br>";
	print HTM_OUT qq!<h3>Results for $protein ($species) [ID: $sys_ID]!;
	if($page_number > 1) { print HTM_OUT " - Page $page_number"; }
	print HTM_OUT qq!</h3>!;
	
	my @lane_ids_arr = @{$lane_ids_ref};

	if($#lane_ids_arr < 0) { print HTM_OUT p("No lanes matched your query."); }
	else
	{
		
		print HTM_OUT "<table rules=all>";

		#print out, by column, the conditions for each lane
		my @reagent_types = Biochemists_Dream::Reagent_Types -> retrieve_from_sql(qq{ Display_Order > 0 ORDER BY Display_Order});
		
		#my @reagent_types = Biochemists_Dream::Reagent_Types -> retrieve_all;
		foreach (@reagent_types)
		{
			print HTM_OUT "<tr>";
			my $name = $_ -> get("Name"); #<div name="l_$lane_id"></div>
			print HTM_OUT "<td><b>$name</b></td>";

			foreach my $lane_id (@{$lane_ids_ref})
			{
				if(defined ${$reagents_ref}{$lane_id}{$name}) { print HTM_OUT "<td >${$reagents_ref}{$lane_id}{$name}</td>"; }
				else { print HTM_OUT "<td >&nbsp;</td>"; }
				
			}
			print HTM_OUT "</tr>";
		}
		
		#ph
		print HTM_OUT "<tr>";
		print HTM_OUT "<td><b>pH</b></td>";
		foreach (@{$ph_ref})
		{ print HTM_OUT "<td >$_</td>"; }
		print HTM_OUT "</tr>";
		
		#over-expressed
		print HTM_OUT "<tr>";
		print HTM_OUT "<td><b>Over Expressed?</b></td>";
		foreach (@{$over_exp_ref})
		{ print HTM_OUT "<td>$_</td>"; }
		print HTM_OUT "</tr>";
		
		#tag type
		print HTM_OUT "<tr>";
		print HTM_OUT "<td><b>Tag Type</b></td>";
		foreach (@{$tag_type_ref})
		{ print HTM_OUT "<td >$_</td>"; }
		print HTM_OUT "</tr>";
		
		#tag location
		print HTM_OUT "<tr>";
		print HTM_OUT "<td><b>Tag Location</b></td>";
		foreach (@{$tag_loc_ref})
		{ print HTM_OUT "<td >$_</td>"; }
		print HTM_OUT "</tr>";
		
		#antibody
		print HTM_OUT "<tr>";
		print HTM_OUT "<td><b>Antibody</b></td>";
		foreach (@{$antibody_ref})
		{ print HTM_OUT "<td >$_</td>"; }
		print HTM_OUT "</tr>";
		
		#other capture
		print HTM_OUT "<tr>";
		print HTM_OUT "<td><b>Other Capture</b></td>";
		foreach (@{$other_cap_ref})
		{ print HTM_OUT "<td >$_</td>"; }
		print HTM_OUT "</tr>";
		
		#notes
		print HTM_OUT "<tr>";
		print HTM_OUT "<td><b>Notes</b></td>";
		foreach (@{$notes_ref})
		{ print HTM_OUT "<td >$_</td>"; }
		print HTM_OUT "</tr>";
		
		#single reagent flag
		print HTM_OUT "<tr>";
		print HTM_OUT "<td><b>Single Reagent</b></td>";
		foreach (@{$single_reagent_flag_ref})
		{ print HTM_OUT "<td >$_</td>"; }
		print HTM_OUT "</tr>";
		
		#elution method
		print HTM_OUT "<tr>";
		print HTM_OUT "<td><b>Elution Method</b></td>";
		foreach (@{$elution_method_ref})
		{ print HTM_OUT "<td >$_</td>"; }
		print HTM_OUT "</tr>";
		
		#elution reagent
		print HTM_OUT "<tr>";
		print HTM_OUT "<td><b>Elution Reagent</b></td>";
		foreach (@{$elution_reagent_ref})
		{ print HTM_OUT "<td >$_</td>"; }
		print HTM_OUT "</tr>";
		
		#Experiment Procedures File link
		print HTM_OUT "<tr>";
		print HTM_OUT "<td><b>Experimental Procedures</b></td>";
		foreach (@{$exp_proc_files_ref})
		{ print HTM_OUT "<td >$_</td>"; }
		print HTM_OUT "</tr>";
		
		#Gel Details File link
		print HTM_OUT "<tr>";
		print HTM_OUT "<td><b>Gel Details</b></td>";
		foreach (@{$gel_details_files_ref})
		{ print HTM_OUT "<td >$_</td>"; }
		print HTM_OUT "</tr>";

		if ($mode eq 'PRIVATE')
		{
			#print out the exp for each lane
			print HTM_OUT "<tr>";
			print HTM_OUT "<td><b>Experiment</b></td>";
			foreach (@{$experiments_ref})
			{ print HTM_OUT "<td>$_</td>"; }
			print HTM_OUT "</tr>";
			
			#print out the project for each lane
			print HTM_OUT "<tr>";
			print HTM_OUT "<td><b>Project</b></td>";
			foreach (@{$projects_ref})
			{ print HTM_OUT "<td>$_</td>"; }
			print HTM_OUT "</tr>";
		}
		else
		{
			#print out the user for each lane
			print HTM_OUT "<tr>";
			print HTM_OUT "<td><b>Submitter</b></td>";
			foreach (@{$users_ref})
			{ print HTM_OUT "<td>$_</td>"; }
			print HTM_OUT "</tr>";
		}
		
		

		#display lane image for each lane
		print HTM_OUT "<tr>";
		print HTM_OUT '<td><b>Lane Image</b><br><br>';
		print HTM_OUT "</td>";
		foreach (@{$img_tags_ref})
		{ print HTM_OUT "<td>$_</td>"; }
		print HTM_OUT "</tr>";
		
		print HTM_OUT "</table>";
		
		
	}

	print HTM_OUT end_html();
	close(HTM_OUT);
	
	return $fname;
	
}

sub display_report_download_page
{
	my $fname = shift;
	
	print header();
	
	print <<HTML;	
<html lang="en">
<head>
<meta charset="utf-8">
<title>copurification.org</title>
<script>
window.location.assign("../copurification/Reports/$fname")
</script>
</head>
<body>
</body>
</html>
HTML
}

sub save_to_contact_list
{
	my $email = shift;
	my @list = ();
	if(open(CONTACT, '<', "$BASE_DIR/contact_list.txt"))
	{
		#read in contact emails, check for repeats
		#add this one to the list
		while (<CONTACT>)
		{
			chomp($_);
			push @list, $_;
		}
		close CONTACT;
	}	
	$email =~ s/^\s*//;
	$email =~ s/\s*$//;
	$email = lc $email;
	my $ignore = 0;
	foreach my $list_email (@list)
	{
		if ($email eq $list_email)
		{
			$ignore = 1;
		}
	}
	
	if (!$ignore)
	{
		if (!open(CONTACT, '>>', "$BASE_DIR/contact_list.txt")) { return 0; }
		else
		{
			print CONTACT "$email\n";
			close(CONTACT);
		}
	}	
	return 1;
}

sub create_lane_grouping_html
{
	my $exp_id = shift;
	my $user_id = shift;
	my $input_file_name = shift;
	my $lane_conditions = shift;
	my %lane_conditions = %{$lane_conditions};
	my @lane_match_list;
	my $min_group_score;
	if (open(IN, "$BASE_DIR/$DATA_DIR/$user_id/Experiments/$exp_id/$input_file_name"))
	{
		my $line = "";
		
		$line = <IN>; #max score
		my $max_score = $line;
		$min_group_score = $MIN_GROUP_RATIO*$max_score;
		
		while ($line = <IN>)
		{
			if ($line =~ /^([^\t]+)\t([\.\d]+)$/)
			{
				push @lane_match_list, [$1,$2]
			}
			else
			{
				if (!$PERFORM_GROUPING)
				{
					push @lane_match_list, ["SKIP",0]
				}
				
			}
			
		}
		if (!$PERFORM_GROUPING)
		{
			while (@lane_match_list)
			{
				my @val = pop @lane_match_list;
				if ($val[0][0] ne "SKIP") { push @lane_match_list, $val[0]; last; }
			}
		}
		
		my $cur_file_list = "";
		my $image_map = "";
		my $html_string = "<tr><td nowrap>";
		my $group_html_string = "";
		my @col_ids;
		push @col_ids, 1;
		my $cur_group_count = 0;
		for(my $j = 0; $j <= $#lane_match_list; $j++)
		{
			my $lane_file = $lane_match_list[$j][0];
			if ($lane_file ne "SKIP")
			{
				$lane_file =~ /(.*[\\\/])([^\\\/]+)\.lane-details\.(\d+)\.txt$/;
				my $dir = $1;
				my $gel_name = $2;
				my $lane_num = $3;
				
				my $conditions="$gel_name lane $lane_num\n";
				foreach my $reagent_type (keys %{$lane_conditions{"$gel_name"}{"$lane_num"}})
				{
					$conditions .= "$reagent_type:\n";
					foreach my $reagent (@{$lane_conditions{"$gel_name"}{"$lane_num"}{"$reagent_type"}})
					{
						$conditions .= "   $reagent\n";
					}
				}
				my $ext = "";
				if (-e "$BASE_DIR/$DATA_DIR/$user_id/Experiments/$exp_id/$gel_name.lane.$lane_num.n.a.png")
				{ $ext = ".a"; }
				
				$group_html_string .= "<img src='/copurification/$user_id/Experiments/$exp_id/$gel_name.lane.$lane_num.n$ext.png' title='$conditions' style='vertical-align: top;'/>";
				$cur_group_count++;
			}
			
			if ((!$PERFORM_GROUPING && $lane_file eq "SKIP") || ($j != $#lane_match_list && $lane_match_list[$j][1] < $min_group_score))
			{
				if ($cur_group_count > 1)
				{
					$html_string .= $group_html_string;
					$html_string .= "</td><td>";
					$html_string .= "<img src='/copurification-html/spacing.png'/>";
					$html_string .= "<img src='/copurification-html/spacing.png'/>";
					$html_string .= "</td><td>";
					
					push @col_ids, 0;
					push @col_ids, 1;
				}
				
				$cur_group_count = 0;
				$group_html_string = "";
			}
		}
		if ($cur_group_count > 1)
		{
			$html_string .= $group_html_string;
		}
		else { pop @col_ids; }
		
		if ($#lane_match_list == -1)
		{
			$html_string .=  "(no groups found)";
		}
		
		$html_string .= "</td></tr></table>";
		
		my $header = "<table>";
		if ($#col_ids > 0)
		{
			$header .= "<tr>";
			my $rn_code = 8544; #roman numeral code
			for(my $i = 0; $i <= $#col_ids; $i++)
			{
				if ($col_ids[$i] == 1) { $header .= "<td align='center' style='border-bottom: solid 1px black;'>&#$rn_code</td>"; $rn_code++; }
				else { $header .= "<td>&nbsp;</td>"; }
			}
			$header .= "</tr>";
			
		}
		$html_string = $header . $html_string;
		return $html_string;
	}
	else
	{
		return "<table><tr><td>Error in creating lane group image: could not open input file: '$BASE_DIR/$DATA_DIR/$user_id/Experiments/$exp_id/$input_file_name'</td></tr></table>";
	}
}

sub add_mass_spect_data_and_file_to_lane
{
	#get   parameter fields from web page
	my @params = param_check();
	my $Exp_Id= param_check('Exp_Id_for_Popup');
	my $Gel_Id = param_check('Gel_Id_for_Popup');
	my $Gel_No = param_check('Gel_No_for_Popup');
	my $lane_id;
	my $Lane_Order = param_check('Lane_Order_for_Popup');
	my $ms_search_engine = param_check('ms_search_engine');
	
	my $mass_spect_file = param('mass_spect_file');
	$mass_spect_file = param_check_file_name('mass_spect_file',$mass_spect_file); 
	
	my $band_or_lane = param_check('band_or_lane');
	my $update_or_delete = param_check('update_or_delete');
	
	#print DEVEL_OUT "Exp_Id=$Exp_Id, Gel_Id=$Gel_Id, Gel_No=$Gel_No, Lane_Order=$Lane_Order, ms_search_engine=$ms_search_engine, band_or_lane=$band_or_lane, update_or_delete=$update_or_delete.";
		
	#retrieve the lane row 	
	my @lanes = Biochemists_Dream::Lane -> retrieve_from_sql( qq { Gel_Id = $Gel_Id AND Lane_Order = $Lane_Order } );
	#update MS_Search_Engine (null if it is deletion)
	my $lane;
	my $redisplay_ext;
	my $redisplay_search_engine;
	foreach $lane (@lanes)
	{
		$lane_id = $lane -> get("Id");
		$redisplay_ext = $lane -> get("MS_File_Suffix");
		$redisplay_search_engine = $lane -> get("MS_Search_Engine");
		
		if ($update_or_delete eq "Delete")
		{
			my $ext = $lane -> get('MS_File_Suffix');
			my $experiment_dir = "$BASE_DIR/$DATA_DIR/$g_user_id/Experiments";
			my $local_ms_fname = "gel$Gel_No.lane.$Lane_Order.ms";
			my $local_fname = "$experiment_dir/$Exp_Id/$local_ms_fname.$ext";
			unlink($local_fname);
			my $set_to_null = undef;
			$lane -> set('MS_Search_Engine' => $set_to_null);
			$lane -> set('MS_File_Suffix' => $set_to_null);
			$lane -> update();
		}
		else
		{
			#lane table update
			if ($mass_spect_file eq "" && (!$lane->get('MS_File_Suffix'))) #allow to keep existing if field left blank
			{
				##param ('Redisplay_Cur_Search_Engine', $redisplay_search_engine);
				##my $experiment_dir = "/copurification/$g_user_id/Experiments";
				##my $local_ms_fname = "gel$Gel_No.lane.$Lane_Order.ms";
				##my $local_fname = "$experiment_dir/$Exp_Id/$local_ms_fname.$redisplay_ext";
				##
				##param ('Redisplay_Cur_Results_File', $local_fname);
				##param ('Lane_Popup_Error_Message', "A mass spec file is required. Please choose a file.");
				##param ('Redisplay_Lane_Popup', 'Yes');
				
				return "A mass spec file is required. Please choose a file.";
			}
			
			if ($mass_spect_file eq "")
			{ #just update ms search engine; file already exists and not changing
				$lane -> set('MS_Search_Engine' => $ms_search_engine);
				$lane -> update();
			}
			else
			{#update file and ms search engine both
				my $extension = $mass_spect_file;
				$extension =~ s/^.*\.([^\.]+)$/$1/;
				my $testres = test_file_extension($extension);	
				if ($testres == 0)
				{
					my $experiment_dir = "$BASE_DIR/$DATA_DIR/$g_user_id/Experiments";
	
					#to resolve deleting of old file enter if logic comparing old to new ext
					#if different delete old file before updating and uploading BA06142016
					#if same extension then do not have to delete first
					my $cur_ext = $lane -> get('MS_File_Suffix');
					my $cur_local_fname = "$experiment_dir/$Exp_Id/gel$Gel_No.lane.$Lane_Order.ms.$cur_ext";
					unlink($cur_local_fname);
	
					$lane -> set('MS_Search_Engine' => $ms_search_engine);
					$lane -> set('MS_File_Suffix' => $extension);
					$lane -> update();
					#MS Results File Upload
					#my $experiment_dir = "/copurification/$g_user_id/Experiments";
					my $local_ms_fname = "gel$Gel_No.lane.$Lane_Order.ms";
					my $local_fname = "$experiment_dir/$Exp_Id/$local_ms_fname";
					
					my $lw_fh = upload('mass_spect_file');
					my $io_fh = $lw_fh -> handle; # Upgrade the handle to one compatible with IO::Handle:
					#if($DEVELOPER_VERSION) { print DEVEL_OUT "About to upload ms file: $mass_spect_file, $local_fname.\n"; }
					my $err_str = upload_file($mass_spect_file, $io_fh, $local_fname); #, $ext);  this is a returned value
					#if($DEVELOPER_VERSION) { print DEVEL_OUT "Exited from upload file.\n"; }
				}
				else
				{
					#MS Results File For Redisplay
					##my $experiment_dir = "/copurification/$g_user_id/Experiments";
					##my $local_ms_fname = "gel$Gel_No.lane.$Lane_Order.ms";
					##my $local_fname = "$experiment_dir/$Exp_Id/$local_ms_fname.$redisplay_ext";
					##param ('Redisplay_Cur_Search_Engine', $redisplay_search_engine);
					##param ('Redisplay_Cur_Results_File', $local_fname);
					##param ('Lane_Popup_Error_Message', "The MS Results File has a bad file extension.  Please select another file.");
					##param ('Redisplay_Lane_Popup', 'Yes');
					
					return "The MS Results File has a bad file extension.  Please select another file.";
				}
			}
		}
	}	
}

sub process_mass_spect_protein_to_band
{
	my @params = param_check();
	my $update_or_delete = param_check('update_or_delete');
	
	#get parameter fields from web page
	my $Exp_Id = param_check('Exp_Id_for_Popup');
	my $Gel_No = param_check('Gel_No_for_Popup');
	my $Lane_Order = param_check('Lane_Order_for_Popup');
	my $Band_Id = param_check('Band_Id_for_File');
	my $ext; #existing ms file suffix
	my $band_protein;
	my $Protein_ID_Method;
	my $mass_spect_file = param_check('mass_spect_file_for_band'); #file entered from web page
	my $ms_protein_id_method = param_check('ms_protein_id_method');
	my $ms_protein_name = param_check('ms_protein_name');
	my $propogate_label = param_check('propogate_label');
	my $propogate_range = param_check('propogate_label_mass_range');
	
	#print DEVEL_OUT "\nprotein name upon input is $ms_protein_name\n";
	#print DEVEL_OUT "in process ms: the lane is $Lane_Order, existing suffix is $ext, no new suffix yet\n";

	if ($update_or_delete eq "Delete")
	{
		#must retrieve band_protein to get information and to delete
		my @band_protein = Biochemists_Dream::Band_Protein -> search(Band_Id => $Band_Id);
		foreach $band_protein (@band_protein)
		{
			#must get extension from band_protein (note - must clear that out also)
			$ext = $band_protein -> get("MS_File_Suffix");
			$Protein_ID_Method = $band_protein -> get("Protein_ID_Method");
			$band_protein->delete;
		}
		#delete the mass spec results file
		if ($Protein_ID_Method eq "mass spec")
		{
			my $experiment_dir = "$BASE_DIR/$DATA_DIR/$g_user_id/Experiments";
			my $local_ms_fname = "gel$Gel_No.lane.$Lane_Order.band.$Band_Id.ms.$ext";
			my $local_fname = "$experiment_dir/$Exp_Id/$local_ms_fname";
			unlink($local_fname);
		}
		#set verified flag to null
		my $band = Biochemists_Dream::Band -> retrieve($Band_Id);
		$band -> set('Used_for_Protein_ID' => undef);
		$band -> update();
		
		return "";
	}
	#falling through means all this code is for processing the addition or updated of a protein
	#
	#first, edit the input fields (note - had ot turn off the required attribure in HTML for now)
	#print DEVEL_OUT "\nprotein name at test is $ms_protein_name\n";
	if ($ms_protein_name eq "")
	{
		##if ($ms_protein_id_method eq "mass spec")
		##{ param ('Turn_On_MS_Input', 'Yes'); }
		##else
		##{ param ('Turn_On_MS_Input', 'No'); }
		##param ('Band_Popup_Error_Message', "Protein has not been entered. Please enter a protein name.");
		##param ('Redisplay_Band_Popup', 'Yes');
		
		return "Protein has not been entered. Please enter a protein name.";
	}
	
	if ($mass_spect_file eq "" and $ms_protein_id_method eq "mass spec")
	{
		#check if there's already existing file first, this is allowed (i.e. protein id method is mass spec)
		my @band_proteins = Biochemists_Dream::Band_Protein -> search(Band_Id => $Band_Id);
		my $id_method="";
		if(scalar(@band_proteins)>0)
		{ $id_method = $band_proteins[0] -> get("Protein_ID_Method"); } # NOTE: all band proteins should have the same ID method
		if ($id_method ne "mass spec") 
		{
			##param ('Turn_On_MS_Input', 'Yes');
			##param ('Band_Popup_Error_Message', "A mass spec file is required. Please choose a file.");
			##param ('Redisplay_Band_Popup', 'Yes');
			return "A mass spec file is required. Please choose a file.";
		}
	}
	if($propogate_label)
	{
		if($propogate_range !~ /^[0-9\.]+$/ || $propogate_range !~ /[0-9]+/ || $propogate_range !~ /\.?/)   
		{
			##param ('Turn_On_MS_Input', 'Yes');
			##param ('Band_Popup_Error_Message', "Band mass range for propogating labels is invalid.  Please enter numerical data.");
			##param ('Redisplay_Band_Popup', 'Yes');
			return "Band mass range for propogating labels is invalid.  Please enter numerical data.";
		}
	}
	
	#once the input fields are checked for entry - they are validated to be sure the values are correct
	#test for bad file extension. if bad do not update anything and return and error message
	if ($ms_protein_id_method eq "mass spec" && $mass_spect_file ne "")
	{
		my $new_extension = $mass_spect_file;
		$new_extension =~ s/^.*\.([^\.]+)$/$1/;
		my $testres = test_file_extension($new_extension);	
		if ($testres == 0)
		{
			my $err_msg = add_upd_mass_spect_protein_to_band ($new_extension);
			return $err_msg;
		}
		else
		{
			##param ('Turn_On_MS_Input', 'Yes');
			##param ('Band_Popup_Error_Message', "The MS Results File has a bad file extension.  Please select another file.");
			##param ('Redisplay_Band_Popup', 'Yes');
			return "The MS Results File has a bad file extension.  Please select another file.";
		}	
	}
	else
	{
		my $err_msg = add_upd_mass_spect_protein_to_band ("");
		return $err_msg;
	}	
}

sub add_upd_mass_spect_protein_to_band 
{
	my @params = param_check();

	my $new_extension = $_[0];

	my $ms_protein_name = param_check('ms_protein_name');
	my $ms_protein_id_method = param_check('ms_protein_id_method');
	my $cur_protein_id = param_check('Protein_Id_for_Rollover');
	my $cur_species = param_check('current_species');
	my $Band_Id = param_check('Band_Id_for_File');
	my $Band_Mass = param_check('Band_Mass_for_Popup');
	my $propogate_label = param_check('propogate_label');
	my $propogate_range = param_check('propogate_label_mass_range');
	my $verified_on_gel = param_check('verified_on_this_gel');

	my $common_name;
	my $Protein_Id;
	my $ms_search_engine;
	my $ms_file_suffix;
	my $band_protein;
	my $id_in_db;
	
	my $Lane_Order = param_check('Lane_Order_for_Popup'); #just for testing
	
	# First Validate the Incoming Protein
	$Biochemists_Dream::GelDataFileReader::species = $cur_species;
	
	print DEVEL_OUT "validating proteins for band: $ms_protein_name, $cur_species\n";
	
	#the $ms_protein_name is one or more proteins in a comma separated list
	my @ms_protein_names = split /,/, $ms_protein_name;
	my @name_errors_list;
	my $j=0;
	for my $name (@ms_protein_names)
	{
		$name =~ s/^\s+|\s+$//g;
		print DEVEL_OUT "VALIDATE: name='$name'\n";
		my $call_validator = validate_protein_name($name, $id_in_db, $common_name);
		print DEVEL_OUT "return from validating protein for band: $call_validator, $name, $cur_species, $id_in_db, $common_name\n";
		
		$Protein_Id = $id_in_db;
		if ($call_validator ==  0)
		{ push @name_errors_list, $name; }
		else
		{
			if ($call_validator == -1) # protein has been found on search engine and must be added to table
			{
				# now must insert row into protein db entry
				my $new_protein = Biochemists_Dream::Protein_DB_Entry -> insert({Protein_DB_Id => $Protein_Id, Systematic_Name => $name,
													 Common_Name => $common_name});
				$Protein_Id = $new_protein -> Id;
			}
		
			#for each band, insert the band_protein and upload file (if id method is mass spec)
			#there will be (possibly) more than one band if propogate_label is true
			
			my @band_id_list=();
			my @lane_order_list=();
			
			push @band_id_list, $Band_Id;
			
			my $band = Biochemists_Dream::Band -> retrieve($Band_Id);
			my $band_mass = $band -> get("Mass");
			my $lane = $band -> Lane_Id;
			my $gel = $lane -> Gel_Id;
			my $gel_id = $gel -> get("Id");
			my $gel_no = $gel -> get("File_Id");
			my $exp_id = $gel -> get("Experiment_Id");
			
			push @lane_order_list, $lane -> get("Lane_Order");
			my $start_lane_id = $lane -> get("Id");
				
			if($propogate_label)
			{
				# search for bands on each lane of gel, within range given (except ladder and quantity std lanes)
				#get gel associated with given band id
				my $band_mass = $band -> get("Mass");
				my @lanes = Biochemists_Dream::Lane -> search(Gel_Id => $gel_id);
				my $cur_lane;
				foreach $cur_lane (@lanes)
				{
					if($cur_lane -> get("Mol_Mass_Cal_Lane") != 1 && $cur_lane -> get("Quantity_Std_Cal_Lane") != 1)
					{
						#look for band at mass
						my $cur_lane_id = $cur_lane -> get("Id");
						if($cur_lane_id != $start_lane_id)
						{
							my @bands = Biochemists_Dream::Band -> search(Lane_Id => $cur_lane_id);
							my $cur_band;
							for $cur_band (@bands)
							{
								my $mass = $cur_band -> get("Mass");
								if(abs($mass-$band_mass) < $propogate_range)
								{
									#add this band id to the list to add a label
									push @band_id_list, $cur_band -> get("Id");
									push @lane_order_list, $cur_lane->get("Lane_Order");
								}
							}
						}
					}
				}
			}
			
			my $band_id_to_label;
			my $i=0;
			my $upload_success=0;
			my $first_ext="";
			
			foreach $band_id_to_label (@band_id_list)
			{
				my $cur_lane_order = $lane_order_list[$i];
				my $ext="";
				
				#if first band, set verified value to input value, else set verified value to No
				my $band = Biochemists_Dream::Band -> retrieve($band_id_to_label);
				if($i==0)
				{
					if($verified_on_gel eq 'Yes') { $band -> set('Used_for_Protein_ID' => 1); }
					else { $band -> set('Used_for_Protein_ID' => 0); }
				}
				else { $band -> set('Used_for_Protein_ID' => 0); }
				$band -> update();
				
				# Delete any previous Band_Protein(s)
				my @band_protein = Biochemists_Dream::Band_Protein -> search(Band_Id => $band_id_to_label);
				foreach $band_protein (@band_protein)
				{
					#must get extension from band_protein (note - must clear that out also)
					$ext = $band_protein -> get("MS_File_Suffix"); #actually, all band_proteins have the same ms file, so same extension
					if($i==0) {$first_ext = $ext; }
					if($j==0) {$band_protein->delete;} # only need to do this once, when adding the first listed protein
				}
				
				# Insert the Band_Protein with new data
				if ($ms_protein_id_method eq "mass spec") 
				{
					$ms_file_suffix = $new_extension;
					$ms_search_engine = param_check('ms_search_engine_for_band');
				} 
				else 
				{
					#null if protein id method is no longer mass spec
					$ms_file_suffix = undef;
					$ms_search_engine = undef;
				}
			
				if($ms_protein_id_method eq "mass spec" && $ms_file_suffix eq "")
				{ $ms_file_suffix=$first_ext; } #there was no file chosen by user, re-use existing file from first band
				
				my $new_band_protein = Biochemists_Dream::Band_Protein ->
							insert({Band_Id => $band_id_to_label,
								Protein_Id => $Protein_Id,
								MS_Search_Engine => $ms_search_engine,
								MS_File_Suffix => $ms_file_suffix,
								Protein_Id_Method => $ms_protein_id_method});
				
				my $experiment_dir = "$BASE_DIR/$DATA_DIR/$g_user_id/Experiments";
				my $local_ms_fname = "gel$gel_no.lane.$cur_lane_order.band.$band_id_to_label.ms";
				my $local_fname = "$experiment_dir/$exp_id/$local_ms_fname.$ext";
				
				if ($j == 0)
				{ # add/replace MS file, only needed to be done for the first protein, same for rest
					if($ms_protein_id_method ne "mass spec" && $ext ne "") { unlink($local_fname); }
					else
					{
						
						#add/upload ms file
						my $mass_spec_file = param('mass_spect_file_for_band');
						if($mass_spec_file ne "")
						{ $mass_spec_file = param_check_file_name('mass_spect_file_for_band', $mass_spec_file); }
						
						#if there's no ms file, 
						#keep/copy the current file, do not do an upload
						#otherwise delete and upload
						
						if(($i==0 && $mass_spec_file ne "") || ($i > 0 && $ext ne "") )
						#if we have a new MS file to upload, delete old one
						#or, if we are propogating, always delete old one if it exists, since we will copy from first band
						{ unlink($local_fname); }
							
						if($i==0)
						{
							#upload file if available/else leave current file
							if ($mass_spec_file ne "") 
							{
								$local_fname = "$experiment_dir/$exp_id/$local_ms_fname";
								my $lw_fh = upload('mass_spect_file_for_band');
								my $io_fh = $lw_fh -> handle; # Upgrade the handle to one compatible with IO::Handle:
								#if($DEVELOPER_VERSION) { print DEVEL_OUT "About to upload ms file: $mass_spec_file, $local_fname.\n"; }
								my $err_str = upload_file($mass_spec_file, $io_fh, $local_fname, $new_extension);
								#if($DEVELOPER_VERSION) { print DEVEL_OUT "Exited from upload file.\n"; }
								if($err_str eq "") { $upload_success=1; }
							}
							else
							{
								#should add check that file does indeed exist
								$upload_success=1;
							}
						}
						else
						{
							#copy file from first upload
							if($upload_success)
							{
								my $copy_file=0;
								my $extension = "";
								if($mass_spec_file ne "")
								{
									$extension = $mass_spec_file;
									if ($extension =~ s/^.*\.([^\.]+)$/$1/)
									{
										$extension = lc $extension;
										$copy_file=1;
									}
								}
								else
								{
									$extension=$first_ext;
									$copy_file=1;
								}
								if($copy_file)
								{
									my $fname_to_write = "$experiment_dir/$exp_id/gel$gel_no.lane.$cur_lane_order.band.$band_id_to_label.ms.$extension";
									my $fname_to_copy = "$experiment_dir/$exp_id/gel$gel_no.lane.$lane_order_list[0].band.$band_id_list[0].ms.$extension";
									copy($fname_to_copy, $fname_to_write)
								}	
							}
						}
						
					}
				}
				$i++;
			}
		}
		$j++;
	}
	if (scalar(@name_errors_list) > 0)
	{
        #param ('Redisplay_MS_Protein_Name', $ms_protein_name);doesn't work - double check this section
		
		##param ('Band_Id_for_Popup', $Band_Id);
		##param ('Band_Mass_for_Popup', $Band_Mass);
		##param ('Redisplay_Band_Popup', 'Yes');
		##
		##my $str = join(',', @name_errors_list);
		##if (scalar(@name_errors_list) > 1)
		##{ param ('Band_Popup_Error_Message', "Proteins '$str' could not be verified and were not added for the band."); }
		##else { param ('Band_Popup_Error_Message', "Protein '$str' could not be verified and was not added for the band."); }
		
		my $str = join(',', @name_errors_list);
		if (scalar(@name_errors_list) > 1)
		{ return "Proteins '$str' could not be verified and were not added for the band."; }
		else { return "Protein '$str' could not be verified and was not added for the band."; }
	}
	else
	{ return ""; }
}

sub retrieve_band_protein { #### NOT USED!! #### 
#online documentation states OO Perl database access does not work on many to many
		my ($data_source, $db_name, $user, $password) = getConfig();
		my $dbh = DBI->connect($data_source, $user, $password, { RaiseError => 1, AutoCommit => 0 });
		my $sql = 'SELECT Protein_Id, MS_Search_Engine, Protein_Id_Method, MS_File_Suffix FROM band_protein WHERE Band_Id = ?';
 		my $sth = $dbh->prepare($sql);
		$sth->execute($_[0]) or die "retrieve band error code: ", $DBI::errstr;
 		my $row_count = $sth->rows;
		if ($row_count > 0)
		{
			my @row = $sth->fetchrow_array;
			my ($Protein_Id, $Search_Engine, $Id_Method, $MS_File_Suffix) = @row;
			$_[1] = $Id_Method;
			$_[2] = $Search_Engine;
			my $Protein_Id_str = $Protein_Id;
			$_[4] = $MS_File_Suffix;
			while ( @row = $sth->fetchrow_array )
			{
				($Protein_Id, $Search_Engine, $Id_Method, $MS_File_Suffix) = @row;
				
				$_[1] = $Id_Method;
				$_[2] = $Search_Engine;
				$Protein_Id_str .= ", $Protein_Id";
				$_[4] = $MS_File_Suffix;
			}
			$_[3] = $Protein_Id_str;
			
			print DEVEL_OUT "In retreive_band_protein: $Protein_Id_str\n";
			
			$sth->finish();
			$dbh->disconnect();
			return 1;
		}
		else
		{
			$sth->finish();
			$dbh->disconnect();
			return 0;
		}

#	Object oriented database access - DOESN'T WORK
		#my @band_protein = Biochemists_Dream::Band_Protein -> search(Band_Id => $_[0]);
		#foreach my $band_protein (@band_protein){
		#	$_[1] = $band_protein -> get("Protein_ID_Method");
		#	$_[2] = $band_protein -> get("MS_Search_Engine");
		#	$_[3] = $band_protein -> get("Protein_ID");
		#	$_[4] = $band_protein -> get("MS_File_Suffix");
		#	
		#}
		#if ($_[3] ne undef) {
		#	return 1;
		#} else { return 0;}
		

}


sub test_file_extension
{
	my $ext_to_test = lc $_[0];
	
	my @bad_extensions = qw/ exe pif application gadget msi msp com scr hta cpl msc jar
				 bat cmd vb vbs vbe js jse ws wsf wsc wsh ps1 ps1xml ps2 ps2xml psc1 psc2
				 msh msh1 msh2 mshxml msh1xml msh2xml
				 scf lnk inf reg doc xls ppt docm dotm xlsm xltm xlam pptm potm ppam ppsm sldm/;
	
	my $testres = 0; # extension is okay
	foreach my $bad_extension (@bad_extensions)
	{
		if ($ext_to_test eq $bad_extension) {
			$testres = 1; # extension is bad
			last;
		}
	}
	return $testres;
}

sub test_for_shared_project {
	#my $project_owner;
	#my ($data_source, $db_name, $user, $password) = getConfig();
	#my $dbh = DBI->connect($data_source, $user, $password, { RaiseError => 1, AutoCommit => 0 });
	#my $sql = 'select User_Id from project where Id IN (select Project_Id from experiment where Id = ?);';
	#my $sth = $dbh->prepare($sql);
	#$sth->execute($_[0]) or die "retrieve project error code: ", $DBI::errstr;
	#my $row_count = $sth->rows;
	#if ($row_count > 0) {
	#	my @row = $sth->fetchrow_array();
	#	   ($project_owner) = @row;
	#}
	#$sth->finish();
	#$dbh->disconnect();
	#
	#if ($project_owner == $g_user_id) 
	#{
	#	return 0; # means no it is not shared and may be updated
	#} else {
	#	return 1; # means yes it is shared
	#}
		
	return 0;
}
