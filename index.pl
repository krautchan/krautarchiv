#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use POSIX qw(ceil);

require "domain/Database.pm";

my $db = Database->new("data/data.db");
my $cgi = new CGI;
my $file_folder = "img";
my $thumb_folder = "thumb";

main();

sub main {
    my $action = $cgi->param('action');
    my $view = $cgi->param('view');
    
    if($action eq "delete_tag") {
        action_delete_tag();
        return;
    } elsif($action eq "add_tag") {
        action_add_tag();
        return;
    }

    if($view eq "board") {
        _board();
    } elsif($view eq "thread") {
        _thread();
    } elsif($view eq "show_file") {
        _show_file();
    } elsif($view eq "top_ten") {
        _top_ten();
    } elsif($view eq "show_files") {
        _show_files();
    } elsif($view eq "tags"){
        _tags();
    } elsif($view eq "tag") {
        _tag();
    } else {
        _index();
    }
}

sub action_add_tag {
    my $tag = $cgi->param('tag');
    my $file_id = $cgi->param('file_id');

    unless($tag && $file_id) {
        _index();
        return;
    }

    my $tags_rowid = $db->add_tag($cgi->escapeHTML($tag));
    $db->add_tag_to_file($tags_rowid,$file_id);

    _show_file();
}

sub action_delete_tag {
    my @tags_rowid_list = $cgi->param('tags_rowid');
    my $file_id = $cgi->param('file_id');

    unless(@tags_rowid_list) {
        _show_file();
        return;
    }
    
    foreach(@tags_rowid_list) {
        $db->delete_tag($_,$file_id);
    }
   _show_file();
}

sub _index {
    require "view/_index.pm";
    my $vars = {menu => menu_()};
    _index::content($vars);
}

sub _board {
    require "view/_board.pm";

    my $board_id = $cgi->param('board_id') || undef;
    my $order = $cgi->param('order') || 0;
    my $page = $cgi->param('page') || 0;
    
    my $limit = 20;
    my $offset = $page * $limit;

    unless($board_id) {
        _index();
        return;
    }
    my $vars = {
        menu => menu_(),
        page => $cgi->escapeHTML($page),
        order => $cgi->escapeHTML($order),
        board_id => $cgi->escapeHTML($board_id)
    };
    my $thread_list = $db->get_thread_list($board_id,$order,$limit,$offset);
    
    foreach(@$thread_list) {
        my $post = $db->get_post($board_id,$_->{thread_id});
        @{$_}{keys %$post} = values %$post;
        $_->{total_answers} = $db->get_total_posts($_->{thread_id});
        $_->{file_list} = $db->get_file_list_by_post($_->{posts_rowid});
        foreach(@{$_->{file_list}}) {
            $_->{thumb} = media_file_($_->{file_id},$_->{path});
        }
    }
    $vars->{total_threads} = $db->get_total_threads($board_id);
    $vars->{max_pages} = ceil($vars->{total_threads} / $limit);
    $vars->{thread_list} = $thread_list;
    _board::content($vars);
}

sub _thread {
    require "view/_thread.pm";

    my $board_id = $cgi->param('board_id') || undef;
    my $thread_id = $cgi->param('thread_id') || undef;

    unless($board_id && $thread_id) {
        _index();
        return;
    }

    my $post_list = $db->get_thread($board_id,$thread_id);

    foreach(@$post_list) {
        $_->{file_list} = $db->get_file_list_by_post($_->{posts_rowid});
        foreach(@{$_->{file_list}}) {
            $_->{thumb} = media_file_($_->{file_id},$_->{path});
        }
    }

    my $vars = { menu => menu_(), post_list => $post_list };
    _thread::content($vars);
}

sub _tags {
    require "view/_tags.pm";
    my $letter = $cgi->param("letter") || 'a';
    
    my $vars = { menu => menu_(), letter => $letter };
    $vars->{tag_list} = $db->get_tag_list_by_letter($letter);

    _tags::content($vars);
}

sub _tag {
    require "view/_tag.pm";
    my $tags_rowid = $cgi->param("tags_rowid");
    my $page = $cgi->param("page");

    my $limit = 20;
    my $offset = $page * $limit;

    my $file_list = $db->get_file_list_by_tag($tags_rowid,$limit,$offset);
    
    foreach(@$file_list) {
        $_->{thumb} = media_file_($_->{file_id},$_->{path});
        $_->{board_list} = $db->get_board_list_by_file_id($_->{file_id});
    }

    my $total_count = $db->get_file_list_by_tag_count($tags_rowid);

    my $vars = {menu => menu_(), file_list => $file_list};
    $vars->{page} = $cgi->escapeHTML($page);
    $vars->{max_pages} = ceil($total_count / $limit);
    $vars->{tags_rowid} = $cgi->escapeHTML($tags_rowid);

    _tag::content($vars);
}

sub _top_ten {
    my $type = $cgi->param('type');

    if($type eq 'files') {
        require "view/_top_ten_files.pm";
        
        my $file_list = $db->get_popular_files_list(10);
        foreach(@{$file_list}) {
            $_->{thumb} = media_file_($_->{file_id},$_->{path});
            $_->{board_list} = $db->get_board_list_by_file_id($_->{file_id});
        }
        
        my $vars = { menu => menu_() };
        $vars->{file_list} = $file_list;
        
        _top_ten_files::content($vars);
    } elsif($type eq 'subjects') {
        require "view/_top_ten_subjects.pm";
        
        my $vars = { menu => menu_()};
        my $subjects_list = $db->get_popular_subjects_list(10);
        $vars->{subjects_list} = $subjects_list;

        _top_ten_subjects::content($vars);
    } else {
        _index();
    }
}

sub _show_files {
    require "view/_show_files.pm";
    my $board = $cgi->param('board') || "%";
    my $filetype = $cgi->param('filetype') || "";
    my $order = $cgi->param('order') || 0;
    my $page = $cgi->param('page') || 0;

    my @filetypes = ("", ".gif", ".mp3", ".ogg", ".swf", ".png", ".jpg",
    ".jpeg", ".psd", ".rar", ".zip", ".torrent");
    
    my $limit = 100;
    if($filetype eq ".gif") {
        $limit = 10;
    } elsif($filetype eq ".mp3") {
        $limit = 5;
    } elsif($filetype eq ".swf") {
        $limit = 1;
    }
    my $offset = $page * $limit;
    my $file_list = $db->get_file_list($filetype,$board,$limit,$offset,$order);
    my $total_count = $db->get_file_list_count($filetype,$board);

    foreach(@$file_list) {
        $_->{thumb} = media_file_($_->{file_id},$_->{path});
        $_->{board_list} = $db->get_board_list_by_file_id($_->{file_id});
    }

    my $vars = { menu => menu_() };
    $vars->{board_list} = $db->get_board_list();
    $vars->{board} = $cgi->escapeHTML($board);
    $vars->{filetype} = $cgi->escapeHTML($filetype);
    $vars->{filetypes} = \@filetypes;
    $vars->{order} = $cgi->escapeHTML($order);
    $vars->{page} = $cgi->escapeHTML($page);
    $vars->{file_list} = $file_list;
    $vars->{total} = $total_count;
    $vars->{max_pages} = ceil($total_count / $limit);
    
    _show_files::content($vars);
}

sub _show_file {
    require "view/_show_file.pm";
    
    my $file_id = $cgi->param('file_id') || undef;

    unless($file_id) {
        _index();
        return;
    }
    
    my $file = $db->get_file($file_id);

    unless($file) {
        _index();
        return;
    }
    
    $file->{path} = "$file_folder/$file->{path}"; 
    my $vars = {menu => menu_(), file => $file};
    $vars->{board_list} = $db->get_board_list_by_file_id($file_id);
    $vars->{tag_list} = $db->get_tag_list_by_file_id($file_id);

    _show_file::content($vars);
}

sub menu_ {
    require "view/_menu.pm";
    
    my $vars = {};
    my $board_list = $db->get_board_list;

    foreach(@$board_list) {
        $_->{thread_count} = $db->get_total_threads($_->{board_id});
    }

    $vars->{board_list} = $board_list;
    $vars->{total_posts} = $db->get_total_posts;
    $vars->{total_files} = $db->get_total_files;
    
    return _menu::content($vars);
}

sub media_file_ {
    my ($file_id,$path) = @_;
    $path = "$file_folder/$path";

    if($path =~ /\.(mp3)|(ogg)$/) {
        return "<audio controls=\"controls\">".
               "<source src=\"$path\" type=\"audio/mp3\" /></audio>";
    } elsif($path =~ /\.swf$/) {
        return "<object data=\"$path\" type=\"application/x-shockwave-flash\">".
               "<param name=\"movie\" value=\"$path\"></object><br />".
               "<a href=$path>Click Me</a>";
    } elsif($path =~ /\.(zip)|(rar)|(torrent)|(psd)$/) {
        return "<a href=$path>$path</a>";
    } elsif($path =~ /\.gif$/) {
        return "<a href=?view=show_file&file_id=$file_id><img src=$path width=200 /></a>";
    } else {
        my $thumbnail = thumbnail_($path);
       return "<a href=?view=show_file&file_id=$file_id><img src=$thumbnail width=200 /></a>";
    }
}

sub thumbnail_ {
    require Image::Imlib2;

    my $path = shift;

    my ($filename) = $path =~ /$file_folder\/(.*)/;
    my $thumbpath = "$thumb_folder/thumbnail$filename";

    if( -e $thumbpath) {
        return $thumbpath;
    }

    my $image = Image::Imlib2->load($path);
    if($image->width > 200) {
        mkdir("thumb");

        my $height = int($image->height / ($image->width/200));
        my $thumb = $image->create_scaled_image(200, $height);
        $thumb->save($thumbpath);
        
        return $thumbpath;
    }
    return $path;
}
