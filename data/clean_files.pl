#!/usr/bin/perl

use strict;
use warnings;

use DBI;

my $dbh = DBI->connect("dbi:SQLite:dbname=data.db", "", "",
                       {PrintError => 1, RaiseError => 1, AutoCommit => 0});

my $sth = $dbh->prepare("SELECT `file_id` FROM `files` WHERE `path` = ?");

my $file_dir = "../img";

opendir(DIR,$file_dir);
my @files = readdir(DIR);
closedir(DIR);

foreach(@files) {        
    if($_ eq "." || $_ eq "..") {
        next;
    }

    $sth->execute($_);
    unless(my ($file_id) = $sth->fetchrow) {
        unlink "$file_dir/$_";
        print "$file_dir/$_ deleted\n";
    }
}

$sth->finish;
$dbh->disconnect;
