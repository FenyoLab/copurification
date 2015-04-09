#!c:/perl/bin/perl.exe

#    (Biochemists_Dream::Common) Common.pm - provides global variables, functions useful to other modules of the program
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

use strict;
use warnings;

package Biochemists_Dream::Common; # assumes Some/Module.pm

BEGIN {

require Exporter;

# set the version for version checking
our $VERSION = 1.00;

# Inherit from Exporter to export functions and variables
our @ISA = qw(Exporter);

# Functions and variables which are exported by default
#our @EXPORT = qw(func1 func2);
our @EXPORT = qw($DATA_DIR $SETTINGS_FILE $EXP_DATA_FILE_NAME_ROOT $GEL_DATA_FILE_NAME_ROOT $LADDER_FILE_NAME_ROOT $PROCESS_GELS_LOG_FILE_NAME $GEL_ERROR_LOG $BASE_DIR
		 %ALLOWED_EXP_PROC_FILE_TYPES %ALLOWED_GEL_DETAILS_FILE_TYPES $IMAGEMAGICK_DIR $WKHTMLTOPDF_DIR $HOSTNAME %ALLOWED_GEL_FILE_TYPES %REAGENT_AMT_UNITS %QUANTITY_STD_UNITS $LANE_OUTPUT_FILE_FORMAT $FIND_LANES_TEMP_DIR read_settings getConfig convert_to_mM);

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

sub getConfig { return ('DBI:mysql:GelDB', 'GelDB', 'admin_user', 'password'); }

sub read_settings
{
	open(SETTINGS_IN, "$SETTINGS_FILE") || return $! . " ($SETTINGS_FILE)";
	my $found = 0;
	while(<SETTINGS_IN>)
	{
		chomp();
		if(/^INSTALL_DIR=(.*)$/) { $BASE_DIR = $1; $found++; }
		elsif(/^ImageMagick=(.*)$/) { $IMAGEMAGICK_DIR = $1; $found++; }
		elsif(/^wkhtmltopdf=(.*)$/) { $WKHTMLTOPDF_DIR = $1; $found++; }
		elsif(/^HOSTNAME=(.*)$/) { $HOSTNAME = $1; $found++; }
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