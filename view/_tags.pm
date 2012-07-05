#!/usr/bin/perl

use strict;
use warnings;

package _tags;

sub content {
    require "view/__head.pm";
    require "view/__foot.pm";

    my $vars = shift;

    __head::content();
    print "$vars->{menu}";

    print "<div class=center>\n";
    
    foreach('a'..'z') {
        if($vars->{letter} eq $_) {
            print " $_ ";
        } else {
            print " <a href=?view=tags&letter=$_>$_</a> ";
        }
    }

    print "</div>\n";
    print "<table><tr>";
    
    my $count = 0;
    foreach(@{$vars->{tag_list}}) {
        print "<td>\n";
        print "<a href=?view=tag&tags_rowid=$_->{tags_rowid}>$_->{tag}</a>";
        print "</td>\n";

        $count++;
        unless($count % 10) {
            print "</tr><tr>\n";
        }
    }

    print "</tr></table>";

    __foot::content();
}
1;
