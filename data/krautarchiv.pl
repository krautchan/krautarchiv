#!/usr/bin/perl

use strict;
use warnings;

use Digest::MD5;
use HTTP::Async;
use HTTP::Request;

require "../domain/Database.pm";
require "../modules/KCParser.pm";
require "../modules/RRD.pm";

my $file_folder = "../img";
my $db_file = "data.db";

# boards that should be archived
my @boards = ('b','int','vip','a','c','co','d','e','f',
              'fb','k','l','li','m','n','p','ph','sp',
              't','tv','v','w','we','x','z','zp','ng',
              'prog','wk','h','s','kc','rfk');

my $async = HTTP::Async->new;
my $file_to_post = {};
my $db = Database->new($db_file);
my $parser = KCParser->new;

# setup
mkdir($file_folder);
$db->setup;

foreach(@boards) {
    $db->add_board($_);
    $async->add(HTTP::Request->new(GET => "http://krautchan.net/$_/0.html"));
}

# main event loop
while(1) {
    eval {
        while(my $res = $async->wait_for_next_response) {
            printf("Scheduled: %u; In Progress: %u; Finished: %u; Current Page: %s\n",
                $async->to_send_count, $async->in_progress_count,
                $async->to_return_count, $res->base);

            # downloaded board page
            if($res->base =~ /(\w{1,4})\/(\d\d?)\.html/) {
                $parser->set_content($res->content);
                my $thread_ids = $parser->parse_thread_ids;

                # schedule found threads to them check for updates
                foreach(@$thread_ids) {
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
            # downloaded thread page
            } elsif($res->base =~ /(\w{1,4})\/thread-(.*)\.html/) {
                # full thread, save it
                if($res->content) {
                    $parser->set_content($res->content);
                    my $file_list = save_thread($1, {
                        content_length => $res->header("Content-Length"),
                        thread_id => $2,
                        post_list => $parser->parse_thread
                        }
                    );
            
                    # schedule files for download
                    foreach(@$file_list) {
                        my $url = "http://krautchan.net/files/$_->{path}";
                        $file_to_post->{$url} = $_;
                        $async->add(HTTP::Request->new(GET => "$url"));
                    }
                # thread head, check if it was updated
                } else {
                    # schedule thread for download if it was updated
                    if(has_thread_changed($1, $2, $res)) {
                        $async->add(HTTP::Request->new(GET => "http://krautchan.net/$1/thread-$2.html"));
                    }
                }
            # downloaded ressource must be a file
            } else {
                save_file($res);
            }
        }
    };
    
    if($@) {
        warn $@;
        $async = HTTP::Async->new;
        foreach(@boards) {
            $async->add(HTTP::Request->new(GET => "http://krautchan.net/$_/0.html"));
        }
    }
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