#!/usr/bin/perl

use strict;
no strict "refs";
use warnings;

use CGI;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use POSIX qw(ceil);
use Template;
use Time::HiRes qw(time);

require "domain/Database.pm";

my $db = Database->new("data/data.db");
my $cgi = new CGI;
my $template = Template->new({ INCLUDE_PATH => 'view',
                               POST_CHOMP   => 0});

my $file_folder = "img";
my $thumb_folder = "thumb";

main();

sub main {
    my $action = $cgi->param('action') || "";
    my $view = $cgi->param('view') || "empty_index";
    
    if($action) {
        &{$action}();
        return;
    }

    &{$view}();
}

sub add_tag {
    my $tag = $cgi->param('tag');
    my $file_id = $cgi->param('file_id');

    unless($tag && $file_id) {
        empty_index();
        return;
    }

    my $tags_rowid = $db->add_tag($cgi->escapeHTML($tag));
    $db->add_tag_to_file($tags_rowid,$file_id);

    show_file();
}

sub delete_tag {
    my @tags_rowid_list = $cgi->param('tags_rowid');
    my $file_id = $cgi->param('file_id');

    unless(@tags_rowid_list) {
        show_file();
        return;
    }
    
    foreach(@tags_rowid_list) {
        $db->delete_tag($_,$file_id);
    }
   show_file();
}

sub empty_index {
    my $vars = {menu => menu_()};
    
    $template->process('index.tmpl', $vars)
}

sub board {
    my $board_id = $cgi->param('board_id') || undef;
    my $order = $cgi->param('order') || 0;
    my $page = $cgi->param('page') || 0;
    
    my $limit = 20;
    my $offset = $page * $limit;

    unless($board_id) {
        empty_index();
        return;
    }
    my $vars = {
        menu => menu_(),
        page => $cgi->escapeHTML($page),
        prev_page => $page - 1,
        next_page => $page + 1,
        order => $cgi->escapeHTML($order),
        board_id => $cgi->escapeHTML($board_id)
    };
    
    my $start_time = time();
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
    my $time = sprintf("%.4f", time() - $start_time);
    
    my $max_pages = ceil($vars->{total_threads} / $limit);
    my @page_list = (0..($max_pages - 1));
    
    
    $vars->{max_pages} = $max_pages;
    $vars->{page_list} = \@page_list;
    $vars->{thread_list} = $thread_list;
    $vars->{time} = $time;
    
    $template->process('board.tmpl', $vars) || print $template->error();;
}

sub thread {
    my $board_id = $cgi->param('board_id') || undef;
    my $thread_id = $cgi->param('thread_id') || undef;

    unless($board_id && $thread_id) {
        empty_index();
        return;
    }
    
    my $start_time = time();
    my $post_list = $db->get_thread($board_id,$thread_id);

    foreach(@$post_list) {
        $_->{file_list} = $db->get_file_list_by_post($_->{posts_rowid});
        foreach(@{$_->{file_list}}) {
            $_->{thumb} = media_file_($_->{file_id},$_->{path});
        }
    }

    my $time = sprintf("%.4f", time() - $start_time);

    my $vars = { menu => menu_(), post_list => $post_list};
    $vars->{time} = $time;
    
    $template->process('thread.tmpl', $vars) || print $template->error();
}

sub tags {
    my $letter = $cgi->param("letter") || 'a';
    
    my $vars = { menu => menu_(), letter => $letter };
    
    my $start_time = time();
    $vars->{tag_list} = $db->get_tag_list_by_letter($letter);
    my $time = sprintf("%.4f", time() - $start_time);
    $vars->{time} = $time;
    
    $template->process('tags.tmpl', $vars) || print $template->error();
}

sub tag {
    my $tags_rowid = $cgi->param("tags_rowid");
    my $page = $cgi->param("page");

    my $limit = 20;
    my $offset = $page * $limit;

    my $start_time = time();
    my $file_list = $db->get_file_list_by_tag($tags_rowid,$limit,$offset);
    
    foreach(@$file_list) {
        $_->{thumb} = media_file_($_->{file_id},$_->{path});
        $_->{board_list} = $db->get_file_info_by_file_id($_->{file_id});
    }

    my $total_count = $db->get_file_list_by_tag_count($tags_rowid);
    my $time = sprintf("%.4f", time() - $start_time);

    my $vars = {menu => menu_(), file_list => $file_list};
    $vars->{page} = $cgi->escapeHTML($page);
    $vars->{prev_page} = $page - 1;
    $vars->{next_page} = $page + 1;
    my $max_pages = ceil($total_count / $limit);
    my @page_list = 0..($max_pages - 1);
    $vars->{max_pages} = $max_pages;
    $vars->{page_list} = \@page_list;
    $vars->{tags_rowid} = $cgi->escapeHTML($tags_rowid);
    $vars->{total} = $total_count;
    $vars->{time} = $time;
    
    $template->process('tag.tmpl', $vars) || print $template->error();
}

sub stats {
    my $board_list = $db->get_board_list();
    
    foreach(@{$board_list}) {
        $_->{thread_count} = $db->get_total_threads($_->{board_id});
        $_->{post_count} = $db->get_total_posts_by_board_id($_->{board_id});
        $_->{posts_per_thread} = sprintf("%.2f",$_->{post_count}/$_->{thread_count});
        $_->{file_count} = $db->get_file_list_count("",$_->{board});
        $_->{text_length} = $db->get_text_length_by_board_id($_->{board_id});
        my $file_list = $db->get_file_list("",$_->{board},-1,0,0);
        
        $_->{size} = 0;
        foreach my $file (@{$file_list}) {
            $_->{size} += -s "$file_folder/$file->{path}";
        }
        $_->{size} = format_bytes_($_->{size});
        $_->{files_per_thread} = sprintf("%.2f",$_->{file_count} / $_->{thread_count});
        ($_->{first_post_time},$_->{last_post_time}) = $db->get_post_time_by_board_id($_->{board_id});
        $_->{threads_per_day} = sprintf("%.2f", $_->{thread_count} / (($_->{last_post_time} - $_->{first_post_time}) / 86400));
        $_->{posts_per_hour} = sprintf("%.2f", $_->{post_count} / (($_->{last_post_time} - $_->{first_post_time}) / 3600));
        $_->{first_post_time} = localtime($_->{first_post_time} - 7200);
        $_->{last_post_time} = localtime($_->{last_post_time} - 7200);
    }

    my $vars = { menu => menu_(), board_list => $board_list };
    $template->process('stats.tmpl', $vars) || print $template->error();
}

sub top_ten {
    my $type = $cgi->param('type');

    if($type eq 'files') {
        my $start_time = time();
        
        my $file_list = $db->get_popular_files_list(10);
        foreach(@{$file_list}) {
            $_->{thumb} = media_file_($_->{file_id},$_->{path});
            $_->{board_list} = $db->get_file_info_by_file_id($_->{file_id});
        }
        my $time = sprintf("%.4f", time() - $start_time);
        
        my $vars = { menu => menu_() };
        $vars->{file_list} = $file_list;
        $vars->{time} = $time;
        
        $template->process('top_ten_files.tmpl', $vars) || print $template->error();
    } elsif($type eq 'subjects') {
        my $vars = { menu => menu_()};
        
        my $start_time = time();
        my $subjects_list = $db->get_popular_subjects_list(10);
        my $time = sprintf("%.4f", time() - $start_time);
        
        $vars->{subjects_list} = $subjects_list;
        $vars->{time} = $time;

        $template->process('top_ten_subjects.tmpl', $vars) || print $template->error();
    } else {
        empty_index();
    }
}

sub show_files {
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
    
    my $start_time = time();
    my $file_list = $db->get_file_list($filetype,$board,$limit,$offset,$order);
    my $total_count = $db->get_file_list_count($filetype,$board);

    foreach(@$file_list) {
        $_->{thumb} = media_file_($_->{file_id},$_->{path});
        $_->{board_list} = $db->get_file_info_by_file_id($_->{file_id});
    }
    my $time = sprintf("%.4f", time() - $start_time);

    my $vars = { menu => menu_() };
    $vars->{board_list} = $db->get_board_list();
    $vars->{board} = $cgi->escapeHTML($board);
    $vars->{filetype} = $cgi->escapeHTML($filetype);
    $vars->{filetypes} = \@filetypes;
    $vars->{order} = $cgi->escapeHTML($order);
    $vars->{page} = $cgi->escapeHTML($page);
    $vars->{prev_page} = $page - 1;
    $vars->{next_page} = $page + 1;
    $vars->{file_list} = $file_list;
    $vars->{total} = $total_count;
    my $max_pages = ceil($total_count / $limit);
    my @page_list = 0..($max_pages - 1);
    $vars->{max_pages} = $max_pages;
    $vars->{page_list} = \@page_list;
    $vars->{time} = $time;
    
    $template->process('show_files.tmpl', $vars) || print $template->error();
    #_show_files::content($vars);
}

sub show_file {
    my $file_id = $cgi->param('file_id') || undef;

    unless($file_id) {
        empty_index();
        return;
    }
    
    my $file = $db->get_file($file_id);

    unless($file) {
        empty_index();
        return;
    }
    
    $file->{path} = "$file_folder/$file->{path}"; 
    my $vars = {menu => menu_(), file => $file};
    $vars->{board_list} = $db->get_file_info_by_file_id($file_id);
    $vars->{tag_list} = $db->get_tag_list_by_file_id($file_id);

    $template->process('show_file.tmpl', $vars) || print $template->error();
}

sub menu_ {
    my $vars = {};
    my $board_list = $db->get_board_list;

    foreach(@$board_list) {
        $_->{thread_count} = $db->get_total_threads($_->{board_id});
    }

    $vars->{board_list} = $board_list;
    $vars->{total_posts} = $db->get_total_posts;
    $vars->{total_files} = $db->get_total_files;
    
    my $menu = '';
    
    $template->process('menu.tmpl', $vars, \$menu);
    
    return $menu;
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

sub format_bytes_ {
    my $number = shift;
    
    my @unit = ("Byte", "KB", "MB", "GB", "TB", "PB");

    my $count = 0;
    while($number > 1024) {
        $number = $number/1024;
        $count++;
    }

    return sprintf("%.2f",$number) . " $unit[$count]";
}

sub AUTOLOAD {
    empty_index();
}
