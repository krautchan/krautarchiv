#!/usr/bin/perl

use strict;
use warnings;

use HTML::Entities ();

package _show_files;

sub content {
    require "view/__head.pm";
    require "view/__foot.pm";
    
    my $vars = shift;

    __head::content();
    print $vars->{menu};
    
    print "<div class=margin>\n";
    print "<form action=\"\" method=get>\n";
    print "<input type=hidden name=view value=show_files />\n";
    print "<select name=board size=1>\n";
    print "<option value=\"%\"></option>\n";

    foreach(@{$vars->{board_list}}) {
        if($vars->{board} eq $_->{board}) {
            print "<option selected>$_->{board}</option>\n";
        } else {
            print "<option>$_->{board}</option>\n";
        }
    }

    print "</select>\n";

    print "<select name=filetype size=1>\n";

    foreach(@{$vars->{filetypes}}) {
        if($vars->{filetype} eq $_) {
            print "<option selected>$_</option>\n";
        } else {
            print "<option>$_</option>\n"
        }
    }

    print "</select>\n";
    print "<select name=order>\n";
    print "<option value=0>ASC</option>\n";
    if($vars->{order} == 1) {
        print "<option selected value=1>DESC</option>\n";
    } else {
        print "<option value=1>DESC</option>\n";
    }
    print "</select>\n";
    print "<input type=submit value=Select>\n";
    print "</form>\n";
    print "</div>\n";

    print "<table><tr>\n";
    
    my $count = 0;
    foreach(@{$vars->{file_list}}) {
        print "<td>\n";
        print "$_->{thumb}\n";

        foreach(@{$_->{board_list}}) {
            print "<br /><a href=?view=board&board_id=$_->{board_id}>$_->{board}</a>/".
                  "<a href=?view=thread&board_id=$_->{board_id}&thread_id=$_->{thread_id}>$_->{thread_id}</a>/".
                  "<a href=?view=thread&board_id=$_->{board_id}&thread_id=$_->{thread_id}#$_->{post_id}>$_->{post_id}</a>";
            print " " . HTML::Entities::encode($_->{filename});
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
        print "<a href=?view=show_files&board=$vars->{board}&filetype=$vars->{filetype}&page=$tmp&order=$vars->{order}>PREV</a>\n";
    }
    
    for(my $i = 0; $i < $vars->{max_pages}; $i++) {
        print "<a href=?view=show_files&board=$vars->{board}&filetype=$vars->{filetype}&page=$i&order=$vars->{order}>$i</a>\n";
    }
    if($vars->{page} < ($vars->{max_pages} - 1)) {
        my $tmp = $vars->{page} + 1;
        print "<a href=?view=show_files&board=$vars->{board}&filetype=$vars->{filetype}&page=$tmp&order=$vars->{order}>NEXT</a>\n";
    }
    print "</div>";

    __foot::content();
}
1;
