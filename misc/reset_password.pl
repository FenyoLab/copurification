##!c:/perl/bin/perl.exe
#Resets the password for a user

use strict;
use warnings;
 
use DBI;

my $dbh;	   
my $result;

my $db_name = "96WellGels";
my $db_admin_user = "96WellGelsAdmin";
my $db_admin_pwd = "proteomics";

my $user_id; my $new_pwd;

if($#ARGV != 1) 
{ print "Format: reset_password.pl <user-id> <new-pwd>\nArg. 1: User Id (from the database)\nArg. 2: new password\n"; exit(0); }
else { $user_id = $ARGV[0]; $new_pwd = $ARGV[1]; }

#connect to db
$dbh = DBI->connect("DBI:mysql:$db_name", $db_admin_user, $db_admin_pwd,  { RaiseError => 1, AutoCommit => 1 }) 
	|| die "Could not connect to database mysql:$db_name as user $db_admin_user: $DBI::errstr";
	
my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
my $password = crypt($new_pwd, $salt);
$result = $dbh -> do(qq!UPDATE User SET Password='$password' WHERE Id='$user_id'!);
	
#disconnect 
$dbh->disconnect();
