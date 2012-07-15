#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use File::Find;

my $dbh = DBI->connect("dbi:SQLite:dbname=data.db", "", "",
                       {PrintError => 1, RaiseError => 1, AutoCommit => 0});

my $sth = $dbh->prepare("SELECT `file_id`,`path` FROM `files`");

my $file_folder = "../img";

find({wanted => \&wanted, no_chdir => 1}, $file_folder);

sub wanted {
    if( -f $File::Find::name) {
        print("$File::Find::name\n");
    }
}

$dbh->disconnect;
