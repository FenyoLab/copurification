#!c:/perl/bin/perl.exe

#    create_my_sql_db.pl - creates the MySQL database for copurification.org.
#    reads from 4 text files which should be in the same directory as this file (these contain the Reagent values)
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

use strict;
use warnings;

use DBI;
use Biochemists_Dream::Common;

my $dbh;	   
my $result;
my $new_db = 0;
my $drop_tables = 0;
my $new_tables = 0;
my $insert_values = 0;
my $root_pwd;

my ($db_source, $db_name, $db_admin_user, $db_admin_pwd) = getConfig();

if($#ARGV != 4) 
{ print "Format: create_mysql_db.pl <root-pwd> <0,1> <0,1> <0,1> <0,1>\nArg. 1: database root password\nArg. 2: 1 if new db is to be created, else 0\nArg. 3: 1 if all tables are to be dropped, else 0\nArg. 4: 1 if new tables are to be created, else 0\nArg. 5: 1 if default data is to be inserted, else 0\n"; exit(0); }
else { $root_pwd = $ARGV[0]; $new_db = $ARGV[1]; $drop_tables = $ARGV[2]; $new_tables = $ARGV[3]; $insert_values = $ARGV[4]; }

#create a database and an admin user
if($new_db)
{
	# Connect to mysql database
	$dbh = DBI->connect("DBI:mysql:mysql", "root", $root_pwd,  { RaiseError => 1, AutoCommit => 1 }) 
		|| die "Could not connect to database mysql as user root: $DBI::errstr";
		
	# ! change to get password from user...
	$result = $dbh -> do(qq!CREATE DATABASE $db_name!);
	$result = $dbh -> do(qq!CREATE USER '$db_admin_user'\@'localhost' IDENTIFIED BY '$db_admin_pwd'!); 
	$result = $dbh -> do(qq!GRANT ALL ON $db_name.* TO $db_admin_user\@localhost!); 
	
	$dbh->disconnect();
}

#now, connect to database...
$dbh = DBI->connect("DBI:mysql:$db_name", $db_admin_user, $db_admin_pwd,  { RaiseError => 1, AutoCommit => 1 }) 
	|| die "Could not connect to database mysql:$db_name as user $db_admin_user: $DBI::errstr";

if($drop_tables)
{
	$result = $dbh -> do(qq!SET FOREIGN_KEY_CHECKS = 0!);
	
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Project!); #
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Experiment!); #
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Species!); #
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Lane!); #
	
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Tag_Types!); #
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Band!);  #
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Gel!); #
	
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Protein_DB!); #
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Protein_DB_Entry!); #
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Band_Protein!); #
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Ladder!); #
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Ladder_Mass!); #
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS User!); #
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Experiment_Procedure!); #
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Reagent!); 
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Reagent_Types!);
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Reagent_Amout_Range!);
	
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Lane_Reagent!);
	
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Expression_Contexts!);
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Expression_Promoters!);
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Modifications!);
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Antibodies!);
	$result = $dbh -> do(qq!DROP TABLE IF EXISTS Other_Capture_Methods!);
	
	
	$result = $dbh -> do(qq!SET FOREIGN_KEY_CHECKS = 1!);
}

#create tables
if($new_tables)
{
	#User table - basis for user accounts to login to the system
	$result = $dbh -> do(qq!
		CREATE TABLE IF NOT EXISTS User
		(Id INT UNSIGNED NOT NULL AUTO_INCREMENT,
		First_Name VARCHAR(255),
		Last_Name VARCHAR(255),
		Institution VARCHAR(255),
		Title VARCHAR(255),
		Email VARCHAR(255) NOT NULL,
		Password VARBINARY(64) NOT NULL,
		ORCID VARCHAR(255),
		Validated BOOL NOT NULL DEFAULT 0,
		Active BOOL NOT NULL DEFAULT 1,
		PRIMARY KEY (Id),
		UNIQUE (Email))!);
	
	#Project Table - Project_Parent_Id is a foreign key and if a parent project is deleted, the child project
	#will be deleted too (CASCADE)
	$result = $dbh -> do(qq!
		CREATE TABLE IF NOT EXISTS Project
		(Id INT UNSIGNED NOT NULL AUTO_INCREMENT,
		 Project_Parent_Id INT UNSIGNED, 
		 User_Id INT UNSIGNED NOT NULL,
		 Name VARCHAR(255) NOT NULL,
		 Description VARCHAR(255), 
		 PRIMARY KEY (Id), 
		 FOREIGN KEY (Project_Parent_Id) REFERENCES Project(Id) ON DELETE CASCADE,
		 FOREIGN KEY (User_Id) REFERENCES User(Id) ON DELETE CASCADE)!);
		
	#Species Table 
	$result = $dbh -> do(qq!
		CREATE TABLE IF NOT EXISTS Species
		(Name VARCHAR(255) NOT NULL,
		PRIMARY KEY (Name))!);
	
	#Experiment Table - Project_Id is a foreign key and if the Project is deleted, the Experiments in it will
	#be deleted too. (CASCADE)
	$result = $dbh -> do(qq!
		CREATE TABLE IF NOT EXISTS Experiment
		(Id INT UNSIGNED NOT NULL AUTO_INCREMENT,
		Project_Id INT UNSIGNED NOT NULL,
		Experiment_Procedure_File VARCHAR(255),
		Gel_Details_File VARCHAR(255),
		Name VARCHAR(255) NOT NULL,
		Species VARCHAR(255) NOT NULL,
		Description VARCHAR(255), 
		PRIMARY KEY (Id),
		FOREIGN KEY (Project_Id) REFERENCES Project(Id) ON DELETE CASCADE,
		FOREIGN KEY (Species) REFERENCES Species(Name) ON DELETE RESTRICT)!);
		
	#Protein_DB Table 
	$result = $dbh -> do(qq!
		CREATE TABLE IF NOT EXISTS Protein_DB
		(Id INT UNSIGNED NOT NULL AUTO_INCREMENT,
		Name VARCHAR(255) NOT NULL,
		Description VARCHAR(255), 
		Link VARCHAR(255),
		Species VARCHAR(255) NOT NULL,
		Priority TINYINT NOT NULL DEFAULT 1,
		PRIMARY KEY (Id),
		FOREIGN KEY (Species) REFERENCES Species(Name) ON DELETE RESTRICT)!);
	
	#Protein_DB_Entry Table 
	$result = $dbh -> do(qq!
		CREATE TABLE IF NOT EXISTS Protein_DB_Entry
		(Id INT UNSIGNED NOT NULL AUTO_INCREMENT,
		Protein_DB_Id INT UNSIGNED NOT NULL,
		Systematic_Name VARCHAR(255) NOT NULL,
		Common_Name VARCHAR(255), 
		Link VARCHAR(255),
		PRIMARY KEY (Id),
		FOREIGN KEY (Protein_DB_Id) REFERENCES Protein_DB(Id) ON DELETE CASCADE)!);
		
	#Gel Table
	$result = $dbh -> do(qq!
		CREATE TABLE IF NOT EXISTS Gel
		(Id INT UNSIGNED NOT NULL AUTO_INCREMENT,
		Experiment_Id INT UNSIGNED NOT NULL,
		File_Id TINYINT NOT NULL,
		File_Type VARCHAR(255) NOT NULL,
		Num_Lanes TINYINT NOT NULL,
		Public BOOL NOT NULL DEFAULT 0,
		Error_Description VARCHAR(255),
		Display_Name VARCHAR(255),
		Date_Submitted TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		PRIMARY KEY (Id),
		FOREIGN KEY (Experiment_Id) REFERENCES Experiment(Id) ON DELETE CASCADE)!);
		
	#Ladder Table
	$result = $dbh -> do(qq!
		CREATE TABLE IF NOT EXISTS Ladder
		(Id INT UNSIGNED NOT NULL AUTO_INCREMENT,
		Name VARCHAR(255),
		PRIMARY KEY (Id))!);
		
	#Ladder Mass Table
	$result = $dbh -> do(qq!
		CREATE TABLE IF NOT EXISTS Ladder_Mass
		(Id INT UNSIGNED NOT NULL AUTO_INCREMENT,
		Ladder_Id INT UNSIGNED NOT NULL,
		Mass DECIMAL(10,2) NOT NULL,
		PRIMARY KEY (Id),
		FOREIGN KEY (Ladder_Id) REFERENCES Ladder(Id) ON DELETE CASCADE)!);
	
	#Tag_Locations Table 
	$result = $dbh -> do(qq!
		CREATE TABLE IF NOT EXISTS Tag_Locations
		(Name VARCHAR(255) NOT NULL,
		PRIMARY KEY (Name))!);
		
	#Lane Table - Ladder_Id is a foreign key and if Ladder is deleted, foreign key in this table will be set to NULL, Lane will not be deleted
	$result = $dbh -> do(qq!
		CREATE TABLE IF NOT EXISTS Lane
		(Id INT UNSIGNED NOT NULL AUTO_INCREMENT,
		Gel_Id INT UNSIGNED NOT NULL,
		Lane_Order TINYINT NOT NULL,
		Error_Description VARCHAR(255),
		Mol_Mass_Cal_Lane BOOL NOT NULL DEFAULT 0,
		Quantity_Std_Cal_Lane BOOL NOT NULL DEFAULT 0,
		Quantity_Std_Name VARCHAR(255),
		Quantity_Std_Amount DECIMAL(10,2),
		Quantity_Std_Units VARCHAR(255),
		Quantity_Std_Size DECIMAL(10,2),
		Ladder_Id INT UNSIGNED,
		Captured_Protein_Id INT UNSIGNED,
		Ph DECIMAL(4,2),
		Over_Expressed BOOL,
		Tag_Location VARCHAR(255),
		Tag_Type VARCHAR(255),
		Antibody VARCHAR(255),
		Other_Capture VARCHAR(255),
		Notes VARCHAR(255),
		PRIMARY KEY (Id),
		FOREIGN KEY (Gel_Id) REFERENCES Gel(Id) ON DELETE CASCADE,
		FOREIGN KEY (Ladder_Id) REFERENCES Ladder(Id) ON DELETE SET NULL,
		FOREIGN KEY (Captured_Protein_Id) REFERENCES Protein_DB_Entry(Id) ON DELETE SET NULL,
		FOREIGN KEY (Tag_Location) REFERENCES Tag_Locations(Name) ON DELETE SET NULL)!);
		
	#Band Table
	$result = $dbh -> do(qq!
		CREATE TABLE IF NOT EXISTS Band
		(Id INT UNSIGNED NOT NULL AUTO_INCREMENT,
		Lane_Id INT UNSIGNED NOT NULL,
		Start_Position INT UNSIGNED NOT NULL,
		End_Position INT UNSIGNED NOT NULL,
		Mass DECIMAL(10,2) NOT NULL,
		Quantity DECIMAL(10,2),
		Mass_Error DECIMAL(10,2),
		Quantity_Error DECIMAL(10,2),
		Captured_Protein BOOL NOT NULL DEFAULT 0,
		PRIMARY KEY (Id),
		FOREIGN KEY (Lane_Id) REFERENCES Lane(Id) ON DELETE CASCADE)!);
	
	#Band_Protein Table
	$result = $dbh -> do(qq!
		CREATE TABLE IF NOT EXISTS Band_Protein
		(Band_Id INT UNSIGNED NOT NULL,
		Protein_Id INT UNSIGNED NOT NULL,
		PRIMARY KEY (Band_Id, Protein_Id),
		FOREIGN KEY (Band_Id) REFERENCES Band(Id) ON DELETE CASCADE,
		FOREIGN KEY (Protein_Id) REFERENCES Protein_DB_Entry(Id) ON DELETE CASCADE)!);
		
	#Reagent_Types Table
	$result = $dbh -> do(qq!
		CREATE TABLE IF NOT EXISTS Reagent_Types
		(Name VARCHAR(255) NOT NULL,
		 Display_Order INT,
		PRIMARY KEY (Name))!);
	
	#Reagent Table
	$result = $dbh -> do(qq!
		CREATE TABLE IF NOT EXISTS Reagent
		(Id INT UNSIGNED NOT NULL AUTO_INCREMENT,
		 Reagent_Type VARCHAR(255) NOT NULL,
		 Name VARCHAR(255) NOT NULL,
		 Short_Name VARCHAR(255),
		 Description VARCHAR(255),
		 Link VARCHAR(255),
		 PRIMARY KEY (Id),                        
		 FOREIGN KEY (Reagent_Type) REFERENCES Reagent_Types(Name) ON DELETE RESTRICT)!);
		
	#Lane_Reagents table - links Reagents and Lanes - should we add Id as PK?  
	$result = $dbh -> do(qq!
		CREATE TABLE IF NOT EXISTS Lane_Reagents
		(Id INT UNSIGNED NOT NULL AUTO_INCREMENT,
		Lane_Id INT UNSIGNED NOT NULL,
		Reagent_Id INT UNSIGNED NOT NULL,
		Amount DECIMAL(10,2) NOT NULL,
		Amount_Units VARCHAR(255) NOT NULL,
		PRIMARY KEY (Id),
		FOREIGN KEY (Lane_Id) REFERENCES Lane(Id) ON DELETE CASCADE,
		FOREIGN KEY (Reagent_Id) REFERENCES Reagent(Id) ON DELETE RESTRICT)!);
	
}

if($insert_values)
{
	
	#Reagent Types
	$result = $dbh -> do(qq!INSERT INTO Reagent_Types (Name, Display_Order) VALUES ('Buffer', 1)!);
	$result = $dbh -> do(qq!INSERT INTO Reagent_Types (Name, Display_Order) VALUES ('Salt', 2)!);
	$result = $dbh -> do(qq!INSERT INTO Reagent_Types (Name, Display_Order) VALUES ('Detergent', 3)!);
	$result = $dbh -> do(qq!INSERT INTO Reagent_Types (Name, Display_Order) VALUES ('Other', 4)!);
	
	#Species
	$result = $dbh -> do(qq!INSERT INTO Species (Name) VALUES ('Homo sapiens')!);
	$result = $dbh -> do(qq!INSERT INTO Species (Name) VALUES ('Saccharomyces cerevisiae')!);
	$result = $dbh -> do(qq!INSERT INTO Species (Name) VALUES ('Escherichia coli')!);
	$result = $dbh -> do(qq!INSERT INTO Species (Name) VALUES ('Mus musculus')!);
	
	#Tag_Locations 
	$result = $dbh -> do(qq!INSERT INTO Tag_Locations (Name) VALUES ('N-term')!);
	$result = $dbh -> do(qq!INSERT INTO Tag_Locations (Name) VALUES ('C-term')!);
	$result = $dbh -> do(qq!INSERT INTO Tag_Locations (Name) VALUES ('internal')!);
	
	#Protein_DB
	$result = $dbh -> do(qq!INSERT INTO Protein_DB (Name, Species) VALUES ('MGI', 'Mus musculus')!);
	$result = $dbh -> do(qq!INSERT INTO Protein_DB (Name, Species) VALUES ('SGD', 'Saccharomyces cerevisiae')!);
	$result = $dbh -> do(qq!INSERT INTO Protein_DB (Name, Species, Priority) VALUES ('RefSeq', 'Homo sapiens', 1)!);
	$result = $dbh -> do(qq!INSERT INTO Protein_DB (Name, Species, Priority) VALUES ('GenBank', 'Homo sapiens', 2)!);
	$result = $dbh -> do(qq!INSERT INTO Protein_DB (Name, Species, Priority) VALUES ('RefSeq', 'Escherichia coli', 1)!);
	$result = $dbh -> do(qq!INSERT INTO Protein_DB (Name, Species, Priority) VALUES ('GenBank', 'Escherichia coli', 2)!);
	
	#REAGENTS:
	
	#read tab delimited text file and input name & short name for each Reagent type
	my @reagent_types = ('Salt', 'Buffer', 'Detergent', 'Other');
	foreach my $reag_type (@reagent_types)
	{
		#open file
		if(!open(IN, "$reag_type.txt")) 
		{
			print "Error: Could not open $reag_type.txt for reading.  Reagents for $reag_type will not be inserted into the database.\n";
			next;
		}
		
		<IN>; #go past header
		
		my $line;
		while($line = <IN>)
		{
			chomp($line);
			if($line =~ /^([^\t]+)\t([^\t]+)$/)
			{
				my $name = $1;
				my $short_name = $2;
				$name =~ s/^"//; $name =~ s/"$//;
				$short_name =~ s/^"//; $short_name =~ s/"$//;
				#print qq!Executing: 'INSERT INTO Reagent (Reagent_Type, Name, Short_Name) VALUES ("$reag_type", "$name", "$short_name"'\n!;
				$result = $dbh -> do(qq!INSERT INTO Reagent (Reagent_Type, Name, Short_Name) VALUES ("$reag_type", "$name", "$short_name")!);
				
			}
			else 
			{
				print "Error: Could not read line in file $reag_type.txt: '$line'.\n";
			}
		}
	}
}

#disconnect 
$dbh->disconnect();