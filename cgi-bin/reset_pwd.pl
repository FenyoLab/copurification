#!/usr/bin/perl
#to reset a user's password
use lib "../lib";

use warnings;
use strict;
use Biochemists_Dream::GelDB;
use Biochemists_Dream::Common; 

my $email = '' #"fred.mast\@cidresearch.org";
my $new_pwd='' #"FREDMAST";

#encrypt password for storing in the database
my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
my $crypt_pwd = crypt($new_pwd, $salt);

my @users = Biochemists_Dream::User -> search(Email => $email);
if($#users < 0)
{ #email not found in db
	print "Error did not find user."
}

my $user = $users[0]; #email is unique key so should be only 1 user

$user -> set('Password' => $crypt_pwd);
$user -> update(); #save to db



	




