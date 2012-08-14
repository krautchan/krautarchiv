#!/usr/bin/perl 

use strict;
use warnings;

require "../modules/RRD.pm";
require "../domain/Database.pm";

my $db = Database->new("data.db");

my $rrd = RRD->new($db);

foreach(('b','int','vip','a','c','co','d','e','f',
         'fb','k','l','li','m','n','p','ph','sp',
         't','tv','v','w','we','x','z','zp','ng',
         'prog','wk','h','s','kc','rfk')) {
    $rrd->update_rrd($_);
}

$rrd->update_graphs();
