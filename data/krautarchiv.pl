#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Digest::MD5;
use Getopt::Long;
use HTTP::Async;
use HTTP::Headers;
use HTTP::Request;
use POSIX qw(setsid);
use Sys::Syslog qw(:standard);

require "../domain/Database.pm";
require "../modules/RRD.pm";


my $config = {};

init_config();
if($config->{help}){
    print_help();
    exit 0;
}

if(!$config->{nodaemon}) {
    daemonize();
    log_me('INFO', "Daemon started");
}
setup_database();
main_loop();


sub init_config {
    $config = { 'boards' => [],
                'file_to_post' => {},
                'db_file' => 'data.db',
                'file_folder' => '../img',
                'useragent' => 'krautarchiv/0x1f (Das Archiv fuer den Bernd von Welt)'
              };

    GetOptions($config, 'boards|b=s@',
                        'db_file|db=s',
                        'debug|d',
                        'file_folder|f=s',
                        'help|h',
                        'nodaemon|n',
                        'useragent|ua=s'
              ) or die("Error while parsing arguments");

    @{$config->{boards}} = split(/,/, join(',', @{$config->{boards}}));
    
    if(!@{$config->{boards}}) {
        $config->{boards} = ['b','int','vip','a','c','co','d','e','f',
                             'fb','k','l','li','m','n','p','ph','sp',
                             't','tv','v','w','we','x','z','zp','ng',
                             'prog','wk','h','s','kc','rfk'];
    }

    $config->{header} = HTTP::Headers->new('User-Agent' => $config->{useragent});
}

sub print_help {
    print "$0 [OPTIONS]\n";
    print "  OPTIONS\n";
    print "    -b BOARDS       Comma seperated list of boards\n";
    print "    -db PATH        Path to database file\n";
    print "    -d              Debug mode\n";
    print "    -f PATH         Folder where images should be saved\n";
    print "    -h              Print this help\n";
    print "    -n              Don't fork into background\n";
    print "    -ua STRING      Set user agent\n";
}

sub log_me {
    my ($priority, $msg) = @_;

    if(!$config->{debug} && $priority eq "DEBUG") {
        return;
    }

    if($config->{nodaemon}) {
        print("$msg\n");
    } else {
        openlog('krautarchiv', 'pid,cons', 'user');
        syslog($priority, $msg);
        closelog();
    }
}

sub daemonize {
    open(STDIN,  "< /dev/null")     || die "can't read /dev/null: $!";
    open(STDOUT, "> /dev/null")     || die "can't write to /dev/null: $!";
    defined(my $pid = fork())       || die "can't fork: $!";
    exit if $pid;                   # non-zero now means I am the parent
    (setsid() != -1)                || die "Can't start a new session: $!"; 
    open(STDERR, ">&STDOUT")        || die "can't dup stdout: $!";
}

sub setup_database {
    $config->{db} = Database->new("data.db");
    mkdir($config->{file_folder});
    $config->{db}->setup;
}

sub main_loop {
    my $async = HTTP::Async->new;
    
    foreach(@{$config->{boards}}) {
        $config->{db}->add_board($_);
        $async->add(HTTP::Request->new('GET', "http://krautchan.net/$_/0.html", $config->{header}));
    }

    while(1) {
        log_me("INFO", "Event loop started");
        eval {
            while(my $res = $async->wait_for_next_response) {
                log_me('DEBUG', sprintf("Scheduled: %u; In Progress: %u; Finished: %u; Current Page: %s",
                             $async->to_send_count, $async->in_progress_count,
                             $async->to_return_count, $res->base));

                # downloaded board page
                if($res->base =~ /(\w{1,4})\/(\d\d?)\.html/) {
                    my @thread_ids = get_thread_urls($res->content);

                    # schedule found threads to them check for updates
                    foreach(@thread_ids) {
                        $async->add(HTTP::Request->new('HEAD', "http://krautchan.net/$1/thread-$_.html", $config->{header}));
                    }

                    # schedule next page
                    my $max = ($1 eq 'b' || $1 eq 'int') ? 15 : 10;
                    my $next = $2 + 1;
                    if($next < $max) {
                        $async->add(HTTP::Request->new('GET', "http://krautchan.net/$1/$next.html", $config->{header}));
                    } else {
                        $async->add(HTTP::Request->new('GET', "http://krautchan.net/$1/0.html", $config->{header}));
                    }
                # downloaded thread page
                } elsif($res->base =~ /(\w{1,4})\/thread-(.*)\.html/) {
                    # full thread, save it
                    if($res->content) {
                        my $file_list = save_thread($1, parse_thread($1, $2, $res));
            
                        # schedule files for download
                        foreach(@$file_list) {
                            my $url = "http://krautchan.net/files/$_->{path}";
                            $config->{file_to_post}->{$url} = $_;
                            $async->add(HTTP::Request->new('GET', "$url", $config->{header}));
                        }
                    # thread head, check if it was updated
                    } else {
                        # schedule thread for download if it was updated
                        if(has_thread_changed($1, $2, $res)) {
                            $async->add(HTTP::Request->new('GET', "http://krautchan.net/$1/thread-$2.html", $config->{header}));
                        }
                    }
                # downloaded ressource must be a file
                } else {
                    save_file($res);
                }
            }
        };
    
        if($@) {
            log_me("WARNING", "$@ - Attempt to reconnect");
            $async = HTTP::Async->new;
            foreach(@{$config->{boards}}) {
                $async->add(HTTP::Request->new('GET', "http://krautchan.net/$_/0.html", $config->{header}));
            }
        }
    }
}

sub save_file {
    my $res = shift;
    
    my $file_info = $config->{file_to_post}->{$res->base} || return;
    delete($config->{file_to_post}->{$res->base});

    my $file_path = "$config->{file_folder}/$file_info->{path}";
    my $posts_rowid = $file_info->{posts_rowid};
    my ($timestamp, $ext) = split(/\./, $file_info->{path});
    
    my $md5 = Digest::MD5->new->add($res->content)->hexdigest;
    
    # file already known
    if(my $file = $config->{db}->get_file_by_md5($md5)) {
        
        my $file_id = $file->{file_id};
        $config->{db}->add_file_to_post($file_id, $posts_rowid, $file_info->{filename});

        log_me('DEBUG', "File: $file_info->{path} MD5: $md5 - duplicate");
    # new file; save it
    } else {
        
        open FILE, ">$config->{file_folder}/$md5.$ext";
        binmode(FILE);
        print FILE $res->content;
        close FILE;

        my $file_id = $config->{db}->add_file("$md5.$ext", $timestamp,$md5);
        $config->{db}->add_file_to_post($file_id, $posts_rowid, $file_info->{filename});
        
        log_me('DEBUG', "File: $file_info->{path} MD5: $md5 - saved");
    }
}

sub save_thread {
    my $board = shift;
    my $thread = shift;
    
    my @file_list = ();

    if(!$thread || !$thread->{thread_id}) {
        log_me('DEBUG', "404 - Das haben wir nicht mehr. Kriegen wir auch nicht mehr rein.");
        return;
    }

    my $board_id = $config->{db}->add_board($board);
    $config->{db}->add_thread_data($board_id, $thread->{thread_id}, 1);

    my $i = 1;
    foreach(@{$thread->{post_list}}) {
        unless($config->{db}->get_post($board_id, $_->{id})) {
            my $posts_rowid = $config->{db}->add_post($board_id, $thread->{thread_id}, $_->{id},
                                                      $_->{subject}, $_->{name},
                                                      $_->{date}, $_->{text});
            log_me('DEBUG', "$i/" . scalar(@{$thread->{post_list}}) . " Board: $board; Thread: $thread->{thread_id}; Post: $_->{id}; - saved");
            foreach my $file(@{$_->{files}}) {
                push(@file_list,{posts_rowid => $posts_rowid, path => $file->{path}, filename => $file->{filename}});
            }
        } else {
            log_me('DEBUG', "$i/" . scalar(@{$thread->{post_list}}) . " Board: $board; Thread: $thread->{thread_id}; Post: $_->{id};");
        }
        $i++;
    }
    $config->{db}->update_thread_data($board_id, $thread->{thread_id}, $thread->{content_length});
    $config->{db}->commit; 
    return \@file_list;
}

sub has_thread_changed {
    my $board = shift;
    my $thread_id = shift;
    my $res = shift;

    if($res->code == 200) {
        my $board_id = $config->{db}->get_board_id($board);
        my $thread_data = $config->{db}->get_thread_data($board_id, $thread_id);
        
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
