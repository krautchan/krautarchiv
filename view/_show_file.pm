#!/usr/bin/perl

use strict;
use warnings;

use HTML::Entities ();

package _show_file;

sub content {
    require "view/__head.pm";
    require "view/__foot.pm";
    
    my $vars = shift;

    __head::content();
    print $vars->{menu};
    
    print "<div class=center><a href=\"$vars->{file}->{path}\"><img class=fileview src=\"$vars->{file}->{path}\" /></a>\n";
    
    foreach(@{$vars->{board_list}}) {
        print "<br /><a href=?view=board&board_id=$_->{board_id}>$_->{board}</a>/".
              "<a href=?view=thread&board_id=$_->{board_id}&thread_id=$_->{thread_id}>$_->{thread_id}</a>/".
              "<a href=?view=thread&board_id=$_->{board_id}&thread_id=$_->{thread_id}#$_->{post_id}>$_->{post_id}</a>";
        print " " . HTML::Entities::encode($_->{filename});
    }
    
    print "<p>Tags:";
    if(@{$vars->{tag_list}}) {
        print "<form action=\"\" method=post>";
        print "<input name=action type=hidden value=delete_tag />\n";
        print "<input name=file_id type=hidden value=$vars->{file}->{file_id} />\n";
        foreach(@{$vars->{tag_list}}) {
            print "<input type=checkbox name=tags_rowid value=$_->{tags_rowid} />$_->{tag}";
        }
        print "<input type=submit value=\"Delete Tag(s)\" />\n";
        print "</form>";
    }
    print "</p>\n";
    print "<form action=\"\" method=post>\n";
    print "<input name=action type=hidden value=add_tag />\n";
    print "<input name=file_id type=hidden value=$vars->{file}->{file_id} />\n";
    print "<input name=tag type=text size=15 maxlength=100 />\n";
    print "<input type=submit value=\"Add Tag\" />\n";
    print "</form>";
    print "</div>\n";

    __foot::content();
}
1;
