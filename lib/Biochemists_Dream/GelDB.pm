#!c:/perl/bin/perl.exe

#    (Biochemists_Dream::GelDB) GelDB.pm - provides class interface to the database - uses Class::DBI
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

use lib "../";

use strict;
use warnings;

############# The base class of Class::DBI for our implementation ########################
package Biochemists_Dream::GelDB;
use base 'Class::DBI';

use Biochemists_Dream::Common;

my ($data_source, $db_name, $user, $password) = getConfig();

Biochemists_Dream::GelDB -> connection($data_source, $user, $password);

############# The Lane_Reagents class ########################
package Biochemists_Dream::Lane_Reagents;
use base 'Biochemists_Dream::GelDB';
Biochemists_Dream::Lane_Reagents -> table('Lane_Reagents');
#Biochemists_Dream::Lane_Reagents -> columns(Primary => qw/Lane_Id Reagent_Id/);
Biochemists_Dream::Lane_Reagents -> columns(Primary => qw/Id/);
Biochemists_Dream::Lane_Reagents -> columns(Others => qw/Lane_Id Reagent_Id Amount Amount_Units/); #added Lane_Id, Reagent_Id
Biochemists_Dream::Lane_Reagents -> has_a(Lane_Id => 'Biochemists_Dream::Lane'); 
Biochemists_Dream::Lane_Reagents -> has_a(Reagent_Id => 'Biochemists_Dream::Reagent');

############# The Reagent class ########################
package Biochemists_Dream::Reagent;
use base 'Biochemists_Dream::GelDB';
Biochemists_Dream::Reagent -> table('Reagent');
Biochemists_Dream::Reagent -> columns(All => qw/Id Reagent_Type Name Short_Name Description Link/);
Biochemists_Dream::Reagent -> has_a(Reagent_Type => 'Biochemists_Dream::Reagent_Types');
Biochemists_Dream::Reagent -> has_many(lane_reagents => 'Biochemists_Dream::Lane_Reagents', { cascade => 'None' });
Biochemists_Dream::Reagent -> has_many(lanes => ['Biochemists_Dream::Lane_Reagents' => 'Lane_Id']);

############# The Reagent_Types class ########################
package Biochemists_Dream::Reagent_Types;
use base 'Biochemists_Dream::GelDB';
Biochemists_Dream::Reagent_Types -> table('Reagent_Types');
Biochemists_Dream::Reagent_Types -> columns(All => qw/Name Display_Order/);

############# The Band_Protein class ########################
package Biochemists_Dream::Band_Protein;
use base 'Biochemists_Dream::GelDB';
Biochemists_Dream::Band_Protein -> table('Band_Protein');
Biochemists_Dream::Band_Protein -> columns(Primary => qw/Band_Id Protein_Id/);
Biochemists_Dream::Band_Protein -> has_a(Band_Id => 'Biochemists_Dream::Band');
Biochemists_Dream::Band_Protein -> has_a(Protein_Id => 'Biochemists_Dream::Protein_DB_Entry');

############# The Band class ########################
package Biochemists_Dream::Band;
use base 'Biochemists_Dream::GelDB';
Biochemists_Dream::Band -> table('Band');
Biochemists_Dream::Band -> columns(All => qw/Id Lane_Id Mass Start_Position End_Position Quantity Mass_Error Quantity_Error Captured_Protein/);
Biochemists_Dream::Band -> has_a(Lane_Id => 'Biochemists_Dream::Lane');
Biochemists_Dream::Band -> has_many(proteins => ['Biochemists_Dream::Band_Protein' => 'Protein_Id']);

############# The Lane class ########################
package Biochemists_Dream::Lane;
use base 'Biochemists_Dream::GelDB';
Biochemists_Dream::Lane -> table('Lane');
Biochemists_Dream::Lane -> columns(All => qw/Id Gel_Id Lane_Order Error_Description Mol_Mass_Cal_Lane Quantity_Std_Cal_Lane Quantity_Std_Name Quantity_Std_Amount
                                   Quantity_Std_Units Quantity_Std_Size Ladder_Id Captured_Protein_Id Ph Over_Expressed Tag_Location Tag_Type Antibody Other_Capture Notes/);
Biochemists_Dream::Lane -> has_many(bands => 'Biochemists_Dream::Band', { cascade => 'None' });
Biochemists_Dream::Lane -> has_many(lane_reagents => 'Biochemists_Dream::Lane_Reagents', { cascade => 'None' });
Biochemists_Dream::Lane -> has_many(reagents => ['Biochemists_Dream::Lane_Reagents' => 'Reagent_Id']);
Biochemists_Dream::Lane -> has_a(Gel_Id => 'Biochemists_Dream::Gel'); 
Biochemists_Dream::Lane -> has_a(Ladder_Id => 'Biochemists_Dream::Ladder'); 
Biochemists_Dream::Lane -> has_a(Captured_Protein_Id => 'Biochemists_Dream::Protein_DB_Entry'); 
Biochemists_Dream::Lane -> has_a(Tag_Location => 'Biochemists_Dream::Tag_Locations');

############# The Gel class ########################
package Biochemists_Dream::Gel;
use base 'Biochemists_Dream::GelDB';
Biochemists_Dream::Gel -> table('Gel');
Biochemists_Dream::Gel -> columns(All => qw/Id Experiment_Id File_Id Num_Lanes Public Error_Description Display_Name File_Type Date_Submitted/);
Biochemists_Dream::Gel -> has_many(lanes => 'Biochemists_Dream::Lane', { order_by => 'Lane_Order' }, { cascade => 'None' }); 
Biochemists_Dream::Gel -> has_a(Experiment_Id => 'Biochemists_Dream::Experiment');

############# The Experiment class ########################
package Biochemists_Dream::Experiment;
use base 'Biochemists_Dream::GelDB';
Biochemists_Dream::Experiment -> table('Experiment');
Biochemists_Dream::Experiment -> columns(All => qw/Id Project_Id Experiment_Procedure_File Gel_Details_File Name Species Description/);
Biochemists_Dream::Experiment -> has_many(gels => 'Biochemists_Dream::Gel', { order_by => 'Display_Name' }, { cascade => 'None' }); 
Biochemists_Dream::Experiment -> has_a(Project_Id => 'Biochemists_Dream::Project'); 
Biochemists_Dream::Experiment -> has_a(Species => 'Biochemists_Dream::Species'); 

############# The Project class ########################
package Biochemists_Dream::Project;
use base 'Biochemists_Dream::GelDB';
Biochemists_Dream::Project -> table('Project');
Biochemists_Dream::Project -> columns(All => qw/Id Project_Parent_Id User_Id Name Description/);
Biochemists_Dream::Project -> has_a(Project_Parent_Id => 'Biochemists_Dream::Project'); 
Biochemists_Dream::Project -> has_a(User_Id => 'Biochemists_Dream::User'); 
Biochemists_Dream::Project -> has_many(projects => 'Biochemists_Dream::Project', { cascade => 'None' }); 
Biochemists_Dream::Project -> has_many(experiments => 'Biochemists_Dream::Experiment', { cascade => 'None' }); 

############# The Protein_DB class ########################
package Biochemists_Dream::Protein_DB;
use base 'Biochemists_Dream::GelDB';
Biochemists_Dream::Protein_DB -> table('Protein_DB');
Biochemists_Dream::Protein_DB -> columns(All => qw/Id Name Description Link Priority Species/);
Biochemists_Dream::Protein_DB -> has_a(Species => 'Biochemists_Dream::Species'); 
Biochemists_Dream::Protein_DB -> has_many(proteins => 'Biochemists_Dream::Protein_DB_Entry', { cascade => 'None' });

############# The Species class ########################
package Biochemists_Dream::Species;
use base 'Biochemists_Dream::GelDB';
Biochemists_Dream::Species -> table('Species');
Biochemists_Dream::Species -> columns(All => qw/Name/);
Biochemists_Dream::Species -> has_many(experiments => 'Biochemists_Dream::Experiment', { cascade => 'None' });

############# The User class ########################
package Biochemists_Dream::User;
use base 'Biochemists_Dream::GelDB';
Biochemists_Dream::User -> table('User');
Biochemists_Dream::User -> columns(All => qw/Id First_Name Last_Name Institution Title Email ORCID Password Validated Active/);
Biochemists_Dream::User -> has_many(projects => 'Biochemists_Dream::Project', { cascade => 'None' }); 

############# The Ladder_Mass class ########################
package Biochemists_Dream::Ladder_Mass;
use base 'Biochemists_Dream::GelDB';
Biochemists_Dream::Ladder_Mass -> table('Ladder_Mass');
Biochemists_Dream::Ladder_Mass -> columns(All => qw/Id Ladder_Id Mass/);
Biochemists_Dream::Ladder_Mass -> has_a(Ladder_Id => 'Biochemists_Dream::Ladder'); #

############# The Ladder class ########################
package Biochemists_Dream::Ladder;
use base 'Biochemists_Dream::GelDB';
 Biochemists_Dream::Ladder -> table('Ladder');
Biochemists_Dream::Ladder -> columns(All => qw/Id Name/);
Biochemists_Dream::Ladder -> has_many(masses => 'Biochemists_Dream::Ladder_Mass', { cascade => 'None' }); #
#Biochemists_Dream::Ladder -> has_many(lanes => 'Biochemists_Dream::Lane', { cascade => 'None' }); 
# MySQL will nullify the necessary rows (Class::DBI take no action) - not general!

############# The Protein_DB_Entry class ########################
package Biochemists_Dream::Protein_DB_Entry;
use base 'Biochemists_Dream::GelDB';
Biochemists_Dream::Protein_DB_Entry -> table('Protein_DB_Entry');
Biochemists_Dream::Protein_DB_Entry -> columns(All => qw/Id Protein_DB_Id Systematic_Name Common_Name Link/);
Biochemists_Dream::Protein_DB_Entry -> has_a(Protein_DB_Id => 'Biochemists_Dream::Protein_DB');
Biochemists_Dream::Protein_DB_Entry -> has_many(bands => ['Biochemists_Dream::Band_Protein' => 'Band_Id']);
Biochemists_Dream::Protein_DB_Entry -> has_many(lanes_captured_by => 'Biochemists_Dream::Lane', { cascade => 'None' }); 
# MySQL will nullify the necessary rows (Class::DBI take no action)  - not general!

############# The Tag_Locations class ########################
package Biochemists_Dream::Tag_Locations;
use base 'Biochemists_Dream::GelDB';
Biochemists_Dream::Tag_Locations -> table('Tag_Locations');
Biochemists_Dream::Tag_Locations -> columns(All => qw/Name/);

1;
