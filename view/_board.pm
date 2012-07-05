#!/usr/bin/perl

use strict;
use warnings;

package _board;

sub content {
    require "view/__head.pm";
    require "view/__foot.pm";
    
    my $vars = shift;

    __head::content();
    print $vars->{menu};
    print "<div class=margin>Sort: <a href=?view=board&board_id=$vars->{board_id}&order=0>Newest</a> ".
          "<a href=?view=board&board_id=$vars->{board_id}&order=1>Most Comments</a></div>";
    
    foreach(@{$vars->{thread_list}}) {
        print "<table class=thread>\n";
        print "<tr class=head><td><a href=?view=thread&thread_id=$_->{thread_id}&board_id=$_->{board_id}>$_->{thread_id}</a> | ";
        print "<span class=subject>$_->{subject}</span> | ";
        print "<span class=username>$_->{user}</span> | $_->{date}\n";
        print "</td></tr>\n";
        print "<tr><td>\n";
        foreach(@{$_->{file_list}}) {
            print "$_->{thumb}\n";
        }
        print "</td></tr><tr><td>\n";
        print "$_->{text}\n";
        print "<p class=count>$_->{total_answers} Posts</p>";
        print "</td></tr>\n";
        print "</table>\n"
    }
    
    print "<div class=margin>\n";
    if($vars->{page}) {
        my $tmp = $vars->{page} - 1;
        print "<a href=?view=board&board_id=$vars->{board_id}&page=$tmp&order=$vars->{order}>PREV</a>\n";
    }
    for(my $i = 0; $i < $vars->{max_pages}; $i++) {
        print "<a href=?view=board&board_id=$vars->{board_id}&page=$i&order=$vars->{order}>$i</a>\n";
    }
    if($vars->{page} < ($vars->{max_pages} - 1)) {
        my $tmp = $vars->{page} + 1;
        print "<a href=?view=board&board_id=$vars->{board_id}&page=$tmp&order=$vars->{order}>NEXT</a>\n";
    }
    print "</div>";
    __foot::content();
}
1;
