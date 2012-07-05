#!/usr/bin/perl

package _menu;

use Carp qw( croak );

sub content {
    my $vars = shift || croak("I need those vars");
    my $content = "";

    $content .= "<div class=\"center\">\n";
    $content .= "<p>\n";
    foreach(@{$vars->{board_list}}) {
        $content .= "[<a href=\"?view=board&board_id=$_->{board_id}\">$_->{board}</a>]($_->{thread_count})\n";
    }
    $content .= "</p>\n";
    $content .= "<p>\n";
    $content .= "<a href=?view=top_ten&type=files>Top 10 Images</a> | ".
                "<a href=?view=top_ten&type=subjects>Top 10 Subjects</a> | ".
                "<a href=?view=show_files>Show Files</a> | ".
                "<a href=?view=tags>Tags</a>";
    $content .= "</p>\n";
    $content .= "<p>\n";
    $content .= "Total Posts: $vars->{total_posts} | Total Files: $vars->{total_files}\n";
    $content .= "</p>\n";
    $content .= "</div>\n";
    return $content;
}
1;
