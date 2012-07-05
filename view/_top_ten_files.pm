#!/usr/bin/perl

use strict;
use warnings;

package _top_ten_files;

sub content {
    require "view/__head.pm";
    require "view/__foot.pm";
    
    my $vars = shift;

    __head::content();
    print $vars->{menu};

    print "<table><tr>\n";
    
    my $count = 0;
    foreach(@{$vars->{file_list}}) {
        print "<td>\n";
        print "$_->{thumb}\n";
        
        foreach(@{$_->{board_list}}) {
            print "<br /><a href=?view=board&board_id=$_->{board_id}>$_->{board}</a>/".
                  "<a href=?view=thread&board_id=$_->{board_id}&thread_id=$_->{thread_id}>$_->{thread_id}</a>/".
                  "<a href=?view=thread&board_id=$_->{board_id}&thread_id=$_->{thread_id}#$_->{post_id}>$_->{post_id}</a>\n";
        }
        print "</td>\n";
        $count++;
        unless($count % 5) {
            $count = 0;
            print "</tr><tr>\n";
        }
    }

    print "</tr><table>\n";
    __foot::content();
}
1;
