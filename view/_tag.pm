#!/usr/bin/perl

use strict;
use warnings;

package _tag;

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
            print "</tr><tr>";
        }
    }
    print "</tr></table>\n";

    print "<div class=margin>\n";
    if($vars->{page}) {
        my $tmp = $vars->{page} - 1;
        print "<a href=?view=tag&tags_rowid=$vars->{tags_rowid}&page=$tmp>PREV</a>\n";
    }
    
    for(my $i = 0; $i < $vars->{max_pages}; $i++) {
        print "<a href=?view=tag&tags_rowid=$vars->{tags_rowid}&page=$i>$i</a>\n";
    }
    if($vars->{page} < ($vars->{max_pages} - 1)) {
        my $tmp = $vars->{page} + 1;
        print "<a href=?view=tag&tags_rowid=$vars->{tags_rowid}&page=$tmp>NEXT</a>\n";
    }
    print "</div>";

    __foot::content();
}
1;
