#!/usr/bin/perl

use strict;
use warnings;

use File::Copy;
use File::Path qw(make_path);
use DBI;
use Digest::MD5;
use LWP;
use Time::Local;

require "../domain/Database.pm";

my $browser = LWP::UserAgent->new;
$browser->agent("Krautarchiv/1.0 - Das Archiv fuer den Bernd von Welt");

my $db = Database->new("data.db");

my $file_folder = "../img";

main(('b','int','vip','a','c','co','d','e','f','fb','k','l','li','m','n','p','ph','sp','t','tv','v','w','we','x','z','zp','ng','prog','wk','h','s','kc','rfk'));

sub main {
    my (@boards) = @_;
    
    mkdir($file_folder);

    $db->setup();
    while(1) {
        foreach(@boards) {
            my $max = 10;
            if($_ eq 'b' || $_ eq 'int') {
                $max = 15;
            }

            for(my $i = 0; $i < $max; $i++) {
                print "Board: $_; Page: $i\n";
                foreach my $thread(get_thread_urls("http://krautchan.net/$_/$i.html")) {
                    if(check_head($thread,$_)) {
                        save_thread(parse_thread($thread,$_),$_);
                    } else {
                        print "SKIP: Board: $_; Thread: $thread\n"
                    }
                }
            }
            update_rrd($_);
        }
    }
}

sub update_rrd {
    my $board = shift;
    
    my $board_id = $db->get_board_id($board);

    my $last_update = 0;
    my $now = $db->get_current_time();
    
    
    if( -e "$board.rrd") {
        $last_update = `rrdtool last $board.rrd`;
        $last_update =~ s/\s//g;
    } else {
        $last_update = $db->get_first_post_time_by_board_id($board_id);
        `rrdtool create $board.rrd -b $last_update --step 300 \\
         DS:posts:GAUGE:600:0:1000 \\
         RRA:AVERAGE:0.5:1:2016`;
    }
    
    my $post_count = $db->get_post_count_by_time_interval($board_id,$last_update,$now,300);
    
    foreach(@{$post_count}) {
        `rrdtool update $board.rrd $_->{time}:$_->{count}`;
        print("Board: $board; Time: $_->{time}/$now $_->{count}\n");
    }
    
    if( -e "$board-year.rrd") {
        $last_update = `rrdtool last $board-year.rrd`;
        $last_update =~ s/\s//g;
    } else {
        $last_update = $db->get_first_post_time_by_board_id($board_id);

        `rrdtool create $board-year.rrd -b $last_update --step 86400 \\
         DS:posts:GAUGE:172800:0:1000000 \\
         RRA:AVERAGE:0.5:1:400`;
    }

    $post_count = $db->get_post_count_by_time_interval($board_id,$last_update,$now,86400);

    foreach(@{$post_count}) {
        `rrdtool update $board-year.rrd $_->{time}:$_->{count}`;
        print("Board: $board; Time: $_->{time}/$now $_->{count}\n");
    }
}

sub get_md5sum {
    my ($path) = @_;
    
    unless( -e $path) {
        return undef;
    }
    
    open FILE, $path;
        binmode(FILE);
        my $md5 = Digest::MD5->new->addfile(*FILE)->hexdigest;
    close FILE;
    return $md5;
}

sub download_file {
    my ($filename) = @_;
    my $path = "$file_folder/$filename";

    if( -e $path) {
        return $path;
    }

    $browser->show_progress(1);
    $browser->mirror("http://krautchan.net/files/$filename", $path);
    $browser->show_progress(0);

    return $path;
}

sub save_files {
    my ($posts_rowid, $post) = @_;

    foreach(@{$post->{files}}) {
        my $md5 = get_md5sum(download_file($_->{path}));
        unless($md5) {
            next;
        }

        my ($timestamp,$ext) = split(/\./,$_->{path});
        my ($f1,$f2,$f3,$f4,$f5,$f6,$f7,$f8) = $md5 =~ /(.{4})/g;

        my $new_path = "$f1/$f2/$f3$f4/$f5$f6";
        make_path("$file_folder/$new_path");
        
        unless (move("$file_folder/$_->{path}", "$file_folder/$new_path/$f7$f8.$ext")) {
            print "$!";
            unlink("$file_folder/$_->{path}");
        }
        $_->{path} = "$new_path/$f7$f8.$ext";

        print "File: $_->{path} MD5: $md5";
        if(my $file = $db->get_file_by_md5($md5)) {
            print " - duplicate\n";
            my $file_id = $file->{file_id};
            $db->add_file_to_post($file_id,$posts_rowid,$_->{filename});
        } else {
            print "- saved\n";
            my $file_id = $db->add_file($_->{path},$timestamp,$md5);
            $db->add_file_to_post($file_id,$posts_rowid,$_->{filename});
        }
    }
}

sub save_thread {
    my ($thread,$board) = @_;
    
    unless($thread) {
        print "404 - Das haben wir nicht mehr. Kriegen wir auch nicht mehr rein.\n";
        return;
    }

    my $thread_id = $thread->{thread_id};
    
    unless($thread_id) {
        print "404 - Das haben wir nicht mehr. Kriegen wir auch nicht mehr rein.\n";
        return;
    }

    my $board_id = $db->add_board($board);
    $db->add_thread_data($board_id,$thread_id,1);

    my $i = 1;
    foreach(@{$thread->{post_list}}) {
        print "$i/" . scalar(@{$thread->{post_list}}) . " Board: $board; Thread: $thread_id; Post: $_->{id};";
        unless($db->get_post($board_id, $_->{id})) {
            my $posts_rowid = $db->add_post($board_id, $thread_id, $_->{id},
                                            $_->{subject}, $_->{name},
                                            $_->{date}, $_->{text});
            print " - saved\n";
            save_files($posts_rowid,$_);
        } else {
            print "\n";
        }
        $i++;
    }
    $db->update_thread_data($board_id,$thread_id,$thread->{content_length});
}

sub check_head {
    my ($thread_id,$board) = @_;
    my $res = $browser->head("http://krautchan.net/$board/thread-$thread_id.html");

    if($res->code == 200) {
        my $board_id = $db->get_board_id($board);
        my $thread_data = $db->get_thread_data($board_id,$thread_id);
        
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
        push(@files,{ filename => $filename, path => $path });
    }

    return \@files;
}

sub parse_thread {
    my ($thread_id,$board) = @_;
    my $res = $browser->get("http://krautchan.net/$board/thread-$thread_id.html");
    
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
    my ($thread_text) = $txt =~ /<p id="post_text_$_[0]">(.*?)<\/p>/;
    my @replies = $txt =~ /<td class=postreply id="post(.*?)<\/td>/g;

    my $post = {};

    parse_post_header($thread_header,$post);
    $post->{files} = parse_post_files(@thread_files);
    $post->{text} = $thread_text;

    push(@post_list, $post);

    foreach(@replies) {
        my @reply_files = $_ =~ /<div class="file_reply">(.*?)<\/div>/g;

        $post = {};
        parse_post_header($_,$post);
        $post->{files} = parse_post_files(@reply_files);
        ($post->{text}) = $_ =~ /<p id="post_text_$post->{id}">(.*?)<\/p>/;
        push(@post_list,$post);
    }
    return { content_length => $content_length,
             thread_id => $thread_id,
             post_list => \@post_list
           };
}

sub get_thread_urls {
    my $response = $browser->get($_[0]);

    return $response->content =~ /<div class="thread" style="clear: both" id="thread_(\d*)">/g;
}
