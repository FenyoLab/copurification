use DBI;
$dbh = DBI->connect('DBI:mysql:copur:db', '', '',
                    { RaiseError => 1, AutoCommit => 0 });
$sth = $dbh->prepare("SELECT * FROM species");
 
$sth->execute();
 
while ( @row = $sth->fetchrow_array ) {
  print "@row\n";
}
