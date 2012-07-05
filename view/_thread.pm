#!/usr/bin/perl

use strict;
use warnings;

package _thread;

sub content {
    require "view/__head.pm";
    require "view/__foot.pm";
    
    my $vars = shift;

    __head::content();
    print $vars->{menu};
    
    foreach(@{$vars->{post_list}}) {
        print "<table class=post>\n";
        print "<tr class=head><td>$_->{post_id}</a> | ";
        print "<span class=subject>$_->{subject}</span> | ";
        print "<span class=username>$_->{user}</span> | $_->{date}\n";
        print "</td></tr>\n";
        print "<tr><td>\n";
        foreach(@{$_->{file_list}}) {
            print "$_->{thumb}\n";
        }
        print "</td></tr><tr><td>\n";
        print "$_->{text}\n";
        print "</td></tr>\n";
        print "</table>\n";
    }

    __foot::content();
}
1;
