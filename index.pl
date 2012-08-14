#!/usr/bin/perl

use strict;
no strict "refs";
use warnings;

use lib ("./modules","./domain");

use CGI::Fast;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use POSIX;
use Template;
use Time::HiRes;

use Database;
use Utilities;

my $file_folder = "img";
my $thumb_folder = "thumb";
my $data_folder = "data";

my $template = Template->new({ INCLUDE_PATH => './view',
                               POST_CHOMP   => 1,
                               TRIM => 0,
                               PRE_PROCESS => 'head.tmpl',
                               POST_PROCESS => 'foot.tmpl'
                              });

while(my $cgi = new CGI::Fast) {
    main($cgi);
}

sub main {
    my ($cgi) = shift;
    my $action = $cgi->param('action') || "";
    my $view = $cgi->param('view') || "empty_index";

    my $db = Database->new("$data_folder/data.db");

    my $vars = { board_list => $db->get_board_list,
                 total_posts => $db->get_total_posts,
                 total_files => $db->get_total_files
               };

    print $cgi->header();

    if($action) {
        &{$action}($cgi,$db,$vars);
        return;
    }

    &{$view}($cgi,$db,$vars);
}

sub add_tag {
    my ($cgi,$db,$vars) = @_;
    my $tag = $cgi->param('tag');
    my $file_id = $cgi->param('file_id');

    unless($tag && $file_id) {
        empty_index($cgi,$db,$vars);
        return;
    }

    my $tag_id = $db->add_tag($cgi->escapeHTML($tag));
    $db->add_tag_to_file($tag_id,$file_id);

    show_file($cgi,$db,$vars);
}

sub delete_file {
    my ($cgi,$db,$vars) = @_;
    my $file_id = $cgi->param('file_id');
    my $view = $cgi->param('view');
    
    my $file = $db->get_file($file_id);
    
    if($db->delete_file($file_id)) {
        unlink("$file_folder/$file->{path}");
        unlink("$thumb_folder/$file_folder/$file->{path}");
    }

    &{$view}($cgi,$db,$vars);
}

sub delete_tag {
    my ($cgi,$db,$vars) = @_;
    my @tag_id_list = $cgi->param('tag_id');
    my $file_id = $cgi->param('file_id');

    unless(@tag_id_list) {
        show_file($cgi,$db,$vars);
        return;
    }
    
    foreach(@tag_id_list) {
        $db->delete_tag($_,$file_id);
    }
   show_file($cgi,$db,$vars);
}

sub empty_index {
    my ($cgi,$db,$vars) = @_;
    $template->process('index.tmpl', $vars) || print $template->error();
}

sub board {
    my ($cgi,$db,$vars) = @_;
    my $board_id = $cgi->param('board_id') || undef;
    my $order = $cgi->param('order') || 0;
    my $page = $cgi->param('page') || 0;
    
    my $limit = 20;
    my $offset = $page * $limit;

    unless($board_id) {
        empty_index($cgi,$db);
        return;
    }
 
    my $start_time = Time::HiRes::time();
    my $thread_list = $db->get_thread_list($board_id,$order,$limit,$offset);
    
    foreach(@$thread_list) {
        foreach(@{$_->{file_list}}) {
            $_->{thumb} = Utilities::create_file_link($_->{file_id},$_->{path},$file_folder,$thumb_folder);
        }
    }
    
    $vars->{total_threads} = $db->get_total_threads($board_id);
    my $time = sprintf("%.4f", Time::HiRes::time() - $start_time);
    
    my $max_pages = ceil($vars->{total_threads} / $limit);
    my @page_list = (0..($max_pages - 1));
    
    $vars->{page} = $cgi->escapeHTML($page);
    $vars->{prev_page} = $page - 1;
    $vars->{next_page} = $page + 1;
    $vars->{order} = $cgi->escapeHTML($order);
    $vars->{board_id} = $cgi->escapeHTML($board_id);
    $vars->{max_pages} = $max_pages;
    $vars->{page_list} = \@page_list;
    $vars->{thread_list} = $thread_list;
    $vars->{time} = $time;
    
    $template->process('board.tmpl', $vars) || print $template->error();
}

sub thread {
    my ($cgi,$db,$vars) = @_;
    my $board_id = $cgi->param('board_id') || undef;
    my $thread_id = $cgi->param('thread_id') || undef;

    unless($board_id && $thread_id) {
        empty_index($cgi, $db, $vars);
        return;
    }

    my $start_time = Time::HiRes::time();
    my $post_list = $db->get_thread($board_id,$thread_id);

    foreach(@$post_list) {
        foreach(@{$_->{file_list}}) {
            $_->{thumb} = Utilities::create_file_link($_->{file_id},$_->{path},$file_folder,$thumb_folder);
        }
    }

    my $time = sprintf("%.4f", Time::HiRes::time() - $start_time);

    $vars->{post_list} = $post_list;
    $vars->{time} = $time;

    $template->process('thread.tmpl', $vars) || print $template->error();
}

sub search {
    my ($cgi,$db,$vars) = @_;
    my $search = $cgi->param('s') || undef;

    unless($search) {
        empty_index($cgi, $db, $vars);
        return;
    }

    my $start_time = Time::HiRes::time();
    my $post_list = $db->search_posts($search);

    my $time = sprintf("%.4f", Time::HiRes::time() - $start_time);

    $vars->{post_list} = $post_list;
    $vars->{time} = $time;

    $template->process('search.tmpl', $vars) || print $template->error();
}

sub tags {
    my ($cgi,$db,$vars) = @_;
    my $letter = $cgi->param("letter") || 'a';

    my $start_time = Time::HiRes::time();
    $vars->{tag_list} = $db->get_tag_list_by_letter($letter);
    my $time = sprintf("%.4f", Time::HiRes::time() - $start_time);

    $vars->{time} = $time;
    $vars->{letter} = $letter;

    $template->process('tags.tmpl', $vars) || print $template->error();
}

sub tag {
    my ($cgi,$db,$vars) = @_;
    my $tag_id = $cgi->param("tag_id");
    my $page = $cgi->param("page");

    my $limit = 20;
    my $offset = $page * $limit;

    my $start_time = Time::HiRes::time();
    my $file_list = $db->get_file_list_by_tag($tag_id,$limit,$offset);
    
    foreach(@$file_list) {
        $_->{thumb} = Utilities::create_file_link($_->{file_id},$_->{path},$file_folder,$thumb_folder);
        $_->{board_list} = $db->get_file_info_by_file_id($_->{file_id});
    }

    my $total_count = $db->get_file_list_by_tag_count($tag_id);
    my $time = sprintf("%.4f", Time::HiRes::time() - $start_time);

    $vars->{file_list} = $file_list;
    $vars->{page} = $cgi->escapeHTML($page);
    $vars->{prev_page} = $page - 1;
    $vars->{next_page} = $page + 1;
    my $max_pages = ceil($total_count / $limit);
    my @page_list = 0..($max_pages - 1);
    $vars->{max_pages} = $max_pages;
    $vars->{page_list} = \@page_list;
    $vars->{tag_id} = $cgi->escapeHTML($tag_id);
    $vars->{total} = $total_count;
    $vars->{time} = $time;

    $template->process('tag.tmpl', $vars) || print $template->error();
}

sub stats {
    my ($cgi,$db,$vars) = @_;
    my $board_list = $db->get_board_list();
    
    foreach(@{$vars->{board_list}}) {
        $_->{post_count} = $db->get_total_posts_by_board_id($_->{board_id});
        $_->{posts_per_thread} = sprintf("%.2f",$_->{post_count}/$_->{thread_count});
        $_->{file_count} = $db->get_file_list_count("",$_->{board_id});
        $_->{text_length} = $db->get_text_length_by_board_id($_->{board_id});
        my $file_list = $db->get_file_list("",$_->{board_id},-1,0,0);
        
        $_->{size} = 0;
        foreach my $file (@{$file_list}) {
            $_->{size} += -s "$file_folder/$file->{path}";
        }
        $_->{size} = Utilities::format_bytes($_->{size});
        $_->{files_per_thread} = sprintf("%.2f",$_->{file_count} / $_->{thread_count});
        ($_->{first_post_time},$_->{last_post_time}) = $db->get_post_time_by_board_id($_->{board_id});
        $_->{threads_per_day} = sprintf("%.2f", $_->{thread_count} / (($_->{last_post_time} - $_->{first_post_time}) / 86400));
        $_->{posts_per_hour} = sprintf("%.2f", $_->{post_count} / (($_->{last_post_time} - $_->{first_post_time}) / 3600));
        $_->{first_post_time} = localtime($_->{first_post_time} - 7200);
        $_->{last_post_time} = localtime($_->{last_post_time} - 7200);
    }

    $template->process('stats.tmpl', $vars) || print $template->error();
}

sub graph {
    my ($cgi,$db,$vars) = @_;
    my $board_id = $cgi->param('board_id') || empty_index($cgi,$db);

    $vars->{board} = $db->get_board($board_id) || empty_index($cgi,$db);
    
    $template->process('graph.tmpl', $vars) || print $template->error();
}

sub top_ten {
    my ($cgi,$db,$vars) = @_;
    my $type = $cgi->param('type');

    if($type eq 'files') {
        my $start_time = Time::HiRes::time();
        
        my $file_list = $db->get_popular_files_list(10);
        foreach(@{$file_list}) {
            $_->{thumb} = Utilities::create_file_link($_->{file_id},$_->{path},$file_folder,$thumb_folder);
            $_->{board_list} = $db->get_file_info_by_file_id($_->{file_id});
        }
        my $time = sprintf("%.4f", Time::HiRes::time() - $start_time);

        $vars->{file_list} = $file_list;
        $vars->{time} = $time;

        $template->process('top_ten_files.tmpl', $vars) || print $template->error();
    } elsif($type eq 'subjects') {

        my $start_time = Time::HiRes::time();
        my $subjects_list = $db->get_popular_subjects_list(10);
        my $time = sprintf("%.4f", Time::HiRes::time() - $start_time);

        $vars->{subjects_list} = $subjects_list;
        $vars->{time} = $time;

        $template->process('top_ten_subjects.tmpl', $vars) || print $template->error();
    } else {
        empty_index($cgi,$db,$vars);
    }
}

sub show_files {
    my ($cgi,$db,$vars) = @_;
    my $board_id = $cgi->param('board_id') || 0;
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

    my $start_time = Time::HiRes::time();
    my $file_list = $db->get_file_list($filetype, $board_id, $limit, $offset, $order);
    my $total_count = $db->get_file_list_count($filetype,$board_id);

    foreach(@$file_list) {
        $_->{thumb} = Utilities::create_file_link($_->{file_id},$_->{path},$file_folder,$thumb_folder);
        $_->{board_list} = $db->get_file_info_by_file_id($_->{file_id});
    }
    my $time = sprintf("%.4f", Time::HiRes::time() - $start_time);

    $vars->{board_id} = $cgi->escapeHTML($board_id);
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
}

sub show_file {
    my ($cgi,$db,$vars) = @_;
    my $file_id = $cgi->param('file_id') || undef;

    unless($file_id) {
        empty_index($cgi,$db,$vars);
        return;
    }

    my $file = $db->get_file($file_id);

    unless($file) {
        empty_index($cgi,$db,$vars);
        return;
    }
    
    $file->{path} = "$file_folder/$file->{path}"; 
    $vars->{file} = $file;
    $vars->{post_list} = $db->get_file_info_by_file_id($file_id);
    $vars->{tag_list} = $db->get_tag_list_by_file_id($file_id);

    $template->process('show_file.tmpl', $vars) || print $template->error();
}

sub AUTOLOAD {
    my ($cgi, $db, $vars) = @_;
    empty_index($cgi, $db, $vars);
}
