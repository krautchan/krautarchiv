#!/usr/bin/perl

use strict;
use warnings;

use Digest::MD5;
use File::Copy;
use HTTP::Async;
use LWP;

require "../domain/Database.pm";
require "../modules/RRD.pm";

my $file_folder = "../img";
my $db_file = "data.db";

# boards that should be archived
my @boards = ('b','int','vip','a','c','co','d','e','f','fb','k','l','li','m','n','p','ph','sp','t','tv','v','w','we','x','z','zp','ng','prog','wk','h','s','kc','rfk');

my $async = HTTP::Async->new;
my $file_to_post = {};
my $db = Database->new($db_file);

# setup
mkdir($file_folder);
$db->setup;

foreach(@boards) {
    $db->add_board($_);
    $async->add( HTTP::Request->new(GET => "http://krautchan.net/$_/0.html"));
}

# main event loop
while(my $res = $async->wait_for_next_response) {
    print $async->info;
    print $res->base."\n";
    
    # downloaded board page
    if($res->base =~ /(\w{1,3})\/(\d\d?)\.html/) {
        my @thread_ids = get_thread_urls($res->content);
        
        # schedule found threads to be checked i they were updated
        foreach(@thread_ids) {
            $async->add(HTTP::Request->new( HEAD => "http://krautchan.net/$1/thread-$_.html"));
        }
        
        # schedule next page
        my $max = ($1 eq 'b' || $1 eq 'int') ? 15 : 10;
        my $next = $2 + 1;
        if($next < $max) {
            $async->add( HTTP::Request->new(GET => "http://krautchan.net/$1/$next.html"));
        } else {
            $async->add( HTTP::Request->new(GET => "http://krautchan.net/$1/0.html"));
        }
        next;
    }
    
    # downloaded thread page
    if($res->base =~ /(\w{1,3})\/thread-(.*)\.html/) {
        
        # full thread, save it
        if($res->content) {
            my $file_list = save_thread($1, parse_thread($1, $2, $res));
            
            # schedule files for download
            foreach(@$file_list) {
                my $url = "http://krautchan.net/files/$_->{path}";
                $file_to_post->{$url} = $_;
                $async->add(HTTP::Request->new( GET => "$url"));
            }
        # thread head, check if it was updated
        } else {
            # schedule thread for download if it was updated
            if(has_thread_changed($1, $2, $res)) {
                $async->add(HTTP::Request->new( GET => "http://krautchan.net/$1/thread-$2.html"));
            }
        }
        next;
    }
    save_file($res);
}

exit;

sub save_file {
    my $res = shift;
    
    my $file_info = $file_to_post->{$res->base} || return;
    delete($file_to_post->{$res->base});

    my $file_path = "$file_folder/$file_info->{path}";
    my $posts_rowid = $file_info->{posts_rowid};
    my ($timestamp, $ext) = split(/\./, $file_info->{path});
    
    my $md5 = Digest::MD5->new->add($res->content)->hexdigest;
    
    # file already known
    if(my $file = $db->get_file_by_md5($md5)) {
        
        my $file_id = $file->{file_id};
        $db->add_file_to_post($file_id, $posts_rowid, $file_info->{filename});

        print "File: $file_info->{path} MD5: $md5 - duplicate\n";
    # new file; save it
    } else {
        
        open FILE, ">$file_folder/$md5.$ext";
        binmode(FILE);
        print FILE $res->content;
        close FILE;

        my $file_id = $db->add_file("$md5.$ext", $timestamp,$md5);
        $db->add_file_to_post($file_id, $posts_rowid, $file_info->{filename});
        
        print "File: $file_info->{path} MD5: $md5 - saved\n";
    }
}

sub save_thread {
    my $board = shift;
    my $thread = shift;
    
    my @file_list = ();

    unless($thread) {
        print "404 - Das haben wir nicht mehr. Kriegen wir auch nicht mehr rein.\n";
        return;
    }
    
    unless($thread->{thread_id}) {
        print "404 - Das haben wir nicht mehr. Kriegen wir auch nicht mehr rein.\n";
        return;
    }

    my $board_id = $db->add_board($board);
    $db->add_thread_data($board_id, $thread->{thread_id}, 1);

    my $i = 1;
    foreach(@{$thread->{post_list}}) {
        print "$i/" . scalar(@{$thread->{post_list}}) . " Board: $board; Thread: $thread->{thread_id}; Post: $_->{id};";
        unless($db->get_post($board_id, $_->{id})) {
            my $posts_rowid = $db->add_post($board_id, $thread->{thread_id}, $_->{id},
                                            $_->{subject}, $_->{name},
                                            $_->{date}, $_->{text});
            print " - saved\n";
            foreach my $file(@{$_->{files}}) {
                push(@file_list,{posts_rowid => $posts_rowid, path => $file->{path}, filename => $file->{filename}});
            }
        } else {
            print "\n";
        }
        $i++;
    }
    $db->update_thread_data($board_id, $thread->{thread_id}, $thread->{content_length});
    $db->commit; 
    return \@file_list;
}

sub has_thread_changed {
    my $board = shift;
    my $thread_id = shift;
    my $res = shift;

    if($res->code == 200) {
        my $board_id = $db->get_board_id($board);
        my $thread_data = $db->get_thread_data($board_id, $thread_id);
        
        if($thread_data) {
            if($res->header("Content-Length") != $thread_data->{content_length}) {
                return $res->header("Content-Length");
            }
        } else {
            return 1;
        }
    }

    return 0;
}

sub parse_post_header {
    my ($txt, $post_ref) = @_;
    ($post_ref->{"id"}, $post_ref->{"subject"}, $post_ref->{"name"}, $post_ref->{"date"}) = $txt =~ /<input name="post_(\d*)" value="delete" type="checkbox"> ?.*? ?<span class="postsubject">(.*?)<\/span> <span class="postername">(.*?)<\/span> <span class="postdate">(.*?)<\/span>/; 
    
    return $post_ref;
}

sub parse_post_files {
    my (@txt) = @_;
    my @files = ();

    foreach(@txt) {
        my ($filename,$path) = $_ =~ /<span id="filename_.*?" style="display:none">(.*?)<\/span>.*?<a href="\/files\/(.*?)" target="_blank">/;
        push(@files, {
                      filename => $filename,
                      path => $path
                     }
            );
    }
    
    return \@files;
}

sub parse_thread {
    my $board = shift;
    my $thread_id = shift;
    my $res = shift;
    
    if($res->is_error) {
        return undef;
    }
    
    my $content_length = $res->header("Content-Length");
    my $txt = $res->content;
    
    my @post_list= ();
    $txt =~ s/\s{2,}/ /g;
    $txt =~ s/\n/ /g;

    my ($thread_header) = $txt =~ /<div class="postheader">(.*?)<\/div>/;
    my @thread_files = $txt =~ /<div class="file_thread">(.*?)<\/div>/g;
    my ($thread_text) = $txt =~ /<p id="post_text_$thread_id">(.*?)<\/p>/;
    my @replies = $txt =~ /<td class=postreply id="post(.*?)<\/td>/g;

    my $post = {};

    parse_post_header($thread_header,$post);
    $post->{files} = parse_post_files(@thread_files);
    $post->{text} = $thread_text;

    push(@post_list, $post);

    foreach(@replies) {
        my @reply_files = $_ =~ /<div class="file_reply">(.*?)<\/div>/g;

        $post = {};
        parse_post_header($_, $post);
        $post->{files} = parse_post_files(@reply_files);
        ($post->{text}) = $_ =~ /<p id="post_text_$post->{id}">(.*?)<\/p>/;
        push(@post_list, $post);
    }

    return {
            content_length => $content_length,
            thread_id => $thread_id,
            post_list => \@post_list
           };
}

sub get_thread_urls {
    my $content = shift;

    return $content =~ /<div class="thread" style="clear: both" id="thread_(\d*)">/g;
}
