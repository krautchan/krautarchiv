#!/usr/bin/perl

use strict;
use warnings;

package _top_ten_subjects;

sub content {
    require "view/__head.pm";
    require "view/__foot.pm";
    
    my $vars = shift;

    __head::content();
    print $vars->{menu};

    print "<table><tr><td>\n";
    
    foreach(@{$vars->{subjects_list}}) {
        print "<span class=subject>$_->{subject}</span> Used $_->{count} times<br />\n";
    }

    print "</td></tr><table>\n";
    __foot::content();
}
1;
