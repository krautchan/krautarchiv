#!/usr/bin/perl

package Database;

use strict;
use warnings;

use DBI;
use Carp qw( croak );

sub new {
    my $type = shift;
    my $db_file = shift;
    my $class = ref $type || $type;

    my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", "", "",{PrintError => 1,AutoCommit => 0});

    my $self = {
        dbh => $dbh
    };

    bless $self, $class;

    return $self;
}

sub add_board {
    my $self = shift;
    my $board = shift || croak("need board");

    my $sth_1 = $self->{dbh}->prepare("INSERT OR IGNORE INTO `boards`(`board`) VALUES(?)");
    my $sth_2 = $self->{dbh}->prepare("SELECT `board_id` FROM `boards` WHERE `board` = ?");

    $sth_1->execute($board);
    $sth_2->execute($board);

    my ($board_id) = $sth_2->fetchrow;
    $self->{dbh}->commit;
    
    return $board_id;
}

sub add_thread_data {
    my $self = shift;
    my $board_id = shift || croak("gibe board_id");
    my $thread_id = shift || croak("gibe thread_id");
    my $content_length = shift || croak("gibe content_length");
    
    my $sth = $self->{dbh}->prepare("INSERT OR IGNORE INTO `threads`(`board_id`,`thread_id`,`content_length`) VALUES (?,?,?)");
    $sth->execute($board_id,$thread_id,$content_length);
    
    $self->{dbh}->commit;
}


sub add_post {
    my $self = shift;
    my $board_id = shift || croak("need board_id");
    my $thread_id = shift || croak("need thread_id");
    my $post_id = shift || croak("need post_id");
    my $subject = shift;
    my $user = shift;
    my $date = shift;
    my $text = shift;

    my $sth_1 = $self->{dbh}->prepare("INSERT OR IGNORE INTO `posts`(`board_id`,`thread_id`,`post_id`,`subject`,`user`,`date`,`text`)
                                       VALUES(?,?,?,?,?,?,?)");

    my $sth_2 = $self->{dbh}->prepare("SELECT `posts_rowid` FROM `posts`
                                       WHERE `board_id` = ? AND `thread_id` = ? AND `post_id` = ?");

    $sth_1->execute($board_id, $thread_id, $post_id, $subject, $user, $date, $text);
    $sth_2->execute($board_id, $thread_id, $post_id);

    my ($posts_rowid) = $sth_2->fetchrow;
    $self->{dbh}->commit;

    return $posts_rowid
}

sub add_file {
    my $self = shift;
    my $path = shift || croak("need path");
    my $timestamp = shift || croak("need timestamp");
    my $md5 = shift || croak("need md5");

    my $sth_1 = $self->{dbh}->prepare("INSERT OR IGNORE INTO `files`(`path`,`timestamp`,`md5`) VALUES(?,?,?)");
    my $sth_2 = $self->{dbh}->prepare("SELECT `file_id` FROM `files` WHERE `md5` = ?");

    $sth_1->execute($path,$timestamp,$md5);
    $sth_2->execute($md5);

    my ($file_id) = $sth_2->fetchrow;
    $self->{dbh}->commit;

    return $file_id;
}

sub add_file_to_post {
    my $self = shift;
    my $file_id = shift || croak("need file_id");
    my $posts_rowid = shift || croak("need posts_rowid");
    my $filename = shift || "";

    my $sth = $self->{dbh}->prepare("INSERT OR IGNORE INTO `post_files`(`file_id`,`posts_rowid`,`filename`) VALUES(?,?,?)");

    $sth->execute($file_id,$posts_rowid,$filename);

    $self->{dbh}->commit;
}


sub add_tag {
    my $self = shift;
    my $tag = shift || croak("need tag");

    my $sth_1 = $self->{dbh}->prepare("INSERT OR IGNORE INTO `tags`(`tag`) VALUES(?)");
    my $sth_2 = $self->{dbh}->prepare("SELECT `tag_id` FROM `tags` WHERE `tag` = ?");

    $sth_1->execute($tag);
    $sth_2->execute($tag);

    my ($tag_id) = $sth_2->fetchrow;
    $self->{dbh}->commit;

    return $tag_id;
}

sub add_tag_to_file {
    my $self = shift;
    my $tag_id = shift || croak("need tag_id");
    my $file_id = shift || croak("need file_id");

    my $sth = $self->{dbh}->prepare("INSERT OR IGNORE INTO `file_tags`(`tag_id`,`file_id`) VALUES(?,?)");

    $sth->execute($tag_id,$file_id);

    $self->{dbh}->commit;
}

sub update_thread_data {
    my $self = shift;
    my $board_id = shift || croak("gibe board_id");
    my $thread_id = shift || croak("gibe thread_id");
    my $content_length = shift || croak("gibe content_length");
    
    my $sth = $self->{dbh}->prepare("UPDATE `threads` SET `content_length` = ?
                                     WHERE `board_id` = ? AND `thread_id` = ?");
                                     
    $sth->execute($content_length,$board_id,$thread_id);
    
    $self->{dbh}->commit;
}


sub get_board {
    my $self = shift;
    my $board_id = shift || croak("need board_id");

    my $sth = $self->{dbh}->prepare("SELECT `board` FROM `boards` WHERE `board_id` = ?");
    $sth->execute($board_id);

    if(my ($board) = $sth->fetchrow) {
        return $board;
    } else {
        return undef;
    }
}

sub get_board_id {
    my $self = shift;
    my $board = shift || croak("need board");

    my $sth = $self->{dbh}->prepare("SELECT `board_id` FROM `boards` WHERE `board` = ?");
    $sth->execute($board);

    if(my ($board_id) = $sth->fetchrow) {
        return $board_id;
    } else {
        return undef;
    }
}

sub get_thread {
    my $self = shift;
    my $board_id = shift || croak("need board_id");
    my $thread_id = shift || croak("need thread_id");

    my $sth = $self->{dbh}->prepare("SELECT `posts_rowid`,`board_id`,`thread_id`,`post_id`,`subject`,`user`,`date`,`text`,`file_id`,`path`,`md5`
                                     FROM `posts`
                                     LEFT JOIN `post_files` USING(`posts_rowid`)
                                     LEFT JOIN `files` USING(`file_id`)
                                     WHERE `board_id` = ? AND `thread_id` = ?
                                     ORDER BY `post_id`,`timestamp` ASC");

    $sth->execute($board_id, $thread_id);

    my @post_list = ();
    my $file_list;
    my $current_posts_rowid = -1;
    while(my ($posts_rowid,$board_id,$thread_id,$post_id,$subject,$user,$date,$text,$file_id,$path,$md5) = $sth->fetchrow) {
        if($current_posts_rowid != $posts_rowid) {
            $current_posts_rowid = $posts_rowid;
            $file_list = _new_array();
            push(@post_list, { posts_rowid => $posts_rowid,
                               board_id => $board_id,
                               thread_id => $thread_id,
                               post_id => $post_id,
                               subject => $subject,
                               user => $user,
                               date => $date,
                               text => $text,
                               file_list => $file_list});
        }
        if($file_id) {
            push(@{$file_list}, { file_id => $file_id, path => $path, md5 => $md5 });
        }
    }

    return \@post_list;
}

sub get_thread_data {
    my $self = shift;
    my $board_id = shift || croak("gibe board_id");
    my $thread_id = shift || croak("give thread_id");

    my $sth = $self->{dbh}->prepare("SELECT `board_id`,`thread_id`,`content_length`
                                     FROM `threads`
                                     WHERE `board_id` = ? AND `thread_id` = ?");
    
    $sth->execute($board_id,$thread_id);
    
    if(my ($bid,$tid,$cl) = $sth->fetchrow) {
        return { board_id => $bid,
                 thread_id => $tid,
                 content_length => $cl
               };
    } else {
        return undef;
    }
}

sub get_post {
    my $self = shift;
    my $board_id = shift || croak("need board_id");
    my $post_id = shift || croak("need post_id");

    my $sth = $self->{dbh}->prepare("SELECT `posts_rowid`,`thread_id`,`subject`,`user`,`date`,`text` FROM `posts`
                                     WHERE `board_id` = ? AND `post_id` = ?");

    $sth->execute($board_id, $post_id);

    if(my ($posts_rowid,$thread_id,$subject,$user,$date,$text) = $sth->fetchrow) {
        return {
            posts_rowid => $posts_rowid,
            thread_id => $thread_id,
            subject => $subject,
            user => $user,
            date => $date,
            text => $text
        }
    } else {
        return undef;
    }
}

sub get_file {
    my $self = shift;
    my $file_id = shift || croak("need file_id");

    my $sth = $self->{dbh}->prepare("SELECT `file_id`, `path`, `md5`
                                     FROM `files` WHERE `file_id` = ?");
    $sth->execute($file_id);

    if(my ($id,$path,$md5) = $sth->fetchrow) {
        return { 
            file_id => $id,
            path => $path,
            md5 => $md5
        };
    } else {
        return undef;
    }
}

sub get_file_by_md5 {
    my $self = shift;
    my $md5 = shift || croak("need md5");

    my $sth = $self->{dbh}->prepare("SELECT `file_id`, `path`, `md5` FROM `files` WHERE `md5` = ?");
    $sth->execute($md5);

    if(my ($file_id,$path,$md5) = $sth->fetchrow) {
        return { 
            file_id => $file_id,
            path => $path,
            md5 => $md5
        };
    } else {
        return undef;
    }
}

sub get_file_info_by_file_id {
    my $self = shift;
    my $file_id = shift || croak("need file_id");

    my $sth = $self->{dbh}->prepare("SELECT `board`,`board_id`,`thread_id`,`post_id`, `file_id`,`filename`
                                     FROM `post_files`
                                     JOIN `posts` USING(`posts_rowid`)
                                     JOIN `boards` USING(`board_id`)
                                     WHERE `file_id` = ?");
    $sth->execute($file_id);

    my @id_list = ();
    while(my ($board, $board_id, $thread_id, $post_id, $fid, $filename) = $sth->fetchrow) {
        push(@id_list,{
                       board => $board,
                       board_id => $board_id,
                       thread_id => $thread_id,
                       post_id => $post_id,
                       file_id => $fid,
                       filename => $filename
                      });
    }

    return \@id_list;
}

sub get_board_list {
    my $self = shift;

    my $sth = $self->{dbh}->prepare("SELECT `board_id`,`board`,COUNT(`threads`)
                                     FROM `boards`
                                     JOIN ( SELECT `board_id`,`thread_id` AS `threads`
                                            FROM `posts` 
                                            GROUP BY `board_id`,`threads`
                                          ) 
                                     USING(`board_id`)
                                     GROUP BY `board_id` ORDER BY `board`");
    my @board_list;

    $sth->execute;
    while(my ($board_id,$board,$thread_count) = $sth->fetchrow) {
        push(@board_list, { board_id => $board_id,
                            board => $board,
                            thread_count => $thread_count });
    }

    return \@board_list;
}

sub get_thread_list {
    my $self = shift;
    my $board_id = shift || croak("need board_id");
    my $order = shift || 0;
    my $limit = shift || -1;
    my $offset = shift || 0;

    my $sth_1;
    
    if($order) {
        $sth_1 = $self->{dbh}->prepare("SELECT `c`,`posts_rowid`,`bid`,`tid`,`post_id`,`subject`,`user`,`date`,`text`,`file_id`,`path`,`md5`
                                        FROM ( SELECT COUNT(*) AS `c`,
                                                     `thread_id` AS `tid`,
                                                     `board_id` AS `bid`
                                               FROM `posts` WHERE `board_id` = ?
                                               GROUP BY `thread_id`
                                             )
                                        JOIN `posts` AS `p` ON `tid` = `p`.`post_id`
                                        AND `bid` = `p`.`board_id`
                                        JOIN `post_files` USING(`posts_rowid`)
                                        JOIN `files` USING(`file_id`)
                                        ORDER BY `c` DESC LIMIT ? OFFSET ?");
    } else {
        $sth_1 = $self->{dbh}->prepare("SELECT `c`,`posts_rowid`,`bid`,`tid`,`post_id`,`subject`,`user`,`date`,`text`,`file_id`,`path`,`md5`
                                        FROM ( SELECT COUNT(*) AS `c`,
                                                     `thread_id` AS `tid`,
                                                     `board_id` AS `bid`
                                               FROM `posts` WHERE `board_id` = ?
                                               GROUP BY `thread_id`
                                             )
                                        JOIN `posts` AS `p` ON `tid` = `p`.`post_id`
                                        AND `bid` = `p`.`board_id`
                                        JOIN `post_files` USING(`posts_rowid`)
                                        JOIN `files` USING(`file_id`)
                                        ORDER BY `thread_id` DESC LIMIT ? OFFSET ?");
    }

    $sth_1->execute($board_id,$limit,$offset);

    my @thread_list;
    my $file_list;
    my $current_posts_rowid = -1;
    while(my ($count,$posts_rowid,$board_id,$thread_id,$post_id,$subject,$user,$date,$text,$file_id,$path,$md5) = $sth_1->fetchrow) {
        if($current_posts_rowid != $posts_rowid) {
            $current_posts_rowid = $posts_rowid;
            $file_list = _new_array();
            push(@thread_list, { total_answers => $count,
                                 posts_rowid => $posts_rowid,
                                 board_id => $board_id,
                                 thread_id => $thread_id,
                                 post_id => $post_id,
                                 subject => $subject,
                                 user => $user,
                                 date => $date,
                                 text => $text,
                                 file_list => $file_list});
        }
        if($file_id) {
            push(@{$file_list}, { file_id => $file_id, path => $path, md5 => $md5 });
        }
    }

    return \@thread_list;
}

sub get_file_list {
    my $self = shift;
    my $file_type = shift || "";
    my $board_id = shift || 0;
    my $limit = shift || -1;
    my $offset = shift || 0;
    my $order = shift || 0;

    if($order) {
        $order = "DESC";
    } else {
        $order = "ASC";
    }
    
    my $comparator = "<>";
    if($board_id) {
        $comparator = "=";
    }

    my $sth = $self->{dbh}->prepare("SELECT `file_id`,`path`,`md5` FROM `files`
                                    JOIN `post_files` USING (`file_id`)
                                    JOIN `posts` USING(`posts_rowid`)
                                    WHERE `path` LIKE ? AND `board_id` $comparator ?
                                    GROUP BY `file_id` ORDER BY `timestamp` $order
                                    LIMIT ? OFFSET ?");

    $sth->execute("%$file_type", $board_id, $limit, $offset);

    my @file_list = ();
    while(my ($file_id,$path,$md5) = $sth->fetchrow) {
        push(@file_list, { file_id => $file_id, path => $path, md5 => $md5 });
    }

    return \@file_list;
}

sub get_file_list_count {
    my $self = shift;
    my $filetype = shift || "";
    my $board_id = shift || 0;

    my $comparator = "<>";
    if($board_id) {
        $comparator = "=";
    }

    my $sth = $self->{dbh}->prepare("SELECT COUNT(*)
                                     FROM (SELECT `path` FROM `files`
                                           JOIN `post_files` USING (`file_id`)
                                           JOIN `posts` USING(`posts_rowid`)
                                           WHERE `path` LIKE ? AND `board_id` $comparator ?
                                           GROUP BY `file_id`)");

    $sth->execute("%$filetype", $board_id);
    my ($count) = $sth->fetchrow;

    return $count;
}

sub get_file_list_by_tag {
    my $self = shift;
    my $tag_id = shift || croak("need tag_id");
    my $limit = shift || 0;
    my $offset = shift || 0;

    my $sth = $self->{dbh}->prepare("SELECT `file_id`,`path`,`md5` FROM `tags`
                                     JOIN `file_tags` USING(`tag_id`)
                                     JOIN `files` USING(`file_id`)
                                     WHERE `tag_id` = ? LIMIT ? OFFSET ?");

    $sth->execute($tag_id,$limit,$offset);

    my @file_list = ();

    while(my ($file_id,$path,$md5) = $sth->fetchrow) {
        push(@file_list,{file_id => $file_id, path => $path, md5 => $md5});
    }

    return \@file_list;
}

sub get_file_list_by_tag_count {
    my $self = shift;
    my $tag_id = shift || croak("need tag_id");

    my $sth = $self->{dbh}->prepare("SELECT COUNT(*) FROM `tags`
                                     JOIN `file_tags` USING(`tag_id`)
                                     JOIN `files` USING(`file_id`)
                                     WHERE `tag_id` = ?");
    
    $sth->execute($tag_id);
    my ($count) = $sth->fetchrow;

    return $count;
}

sub get_tag_list_by_file_id {
    my $self = shift;
    my $file_id = shift || croak("need file_id");

    my $sth = $self->{dbh}->prepare("SELECT `tag_id`,`tag` FROM `tags`
                                     JOIN `file_tags` USING (`tag_id`)
                                     JOIN `files` USING (`file_id`)
                                     WHERE `file_id` = ?");

    $sth->execute($file_id);

    my @tag_list = ();
    
    while(my ($tag_id,$tag) = $sth->fetchrow) {
        push(@tag_list, { tag_id => $tag_id, tag => $tag });
    }

    return \@tag_list;
}

sub get_tag_list_by_letter {
    my $self = shift;
    my $letter = shift || "";

    my $sth = $self->{dbh}->prepare("SELECT `tag_id`,`tag` FROM `tags` WHERE `tag` LIKE ?");

    $sth->execute("$letter%");

    my @tag_list;
    while(my ($tag_id,$tag) = $sth->fetchrow) {
        push(@tag_list, { tag_id => $tag_id, tag=>$tag });
    }
    return \@tag_list;
}

sub get_post_time_by_board_id {
    my $self = shift;
    my $board_id = shift || croak("need board id");

    my $sth = $self->{dbh}->prepare("SELECT strftime('%s',min(`date`)),strftime('%s',max(`date`)) FROM `posts`
                                     WHERE `board_id` = ?");
    $sth->execute($board_id);
    if(my ($min,$max) = $sth->fetchrow) {
        return ($min, $max);
    } else {
        return ();
    }
}

sub get_post_count_by_time_interval {
    my $self = shift;
    my $board_id = shift || croak("need board_id");
    my $start_time = shift || croak("need start_time");
    my $stop_time = shift || croak("need stop_time");
    my $interval = shift || croak("need interval");

    my $sth = $self->{dbh}->prepare("SELECT COUNT(*) FROM `posts`
                                     WHERE `board_id` = ?
                                     AND ? <= strftime(\"%s\",`date`)
                                     AND strftime(\"%s\",`date`) < ?
                                     ORDER BY `date`");

    my  @post_count = ();
    for(my $i = $start_time; $i <= $stop_time - $interval; $i += $interval) {
        $sth->execute($board_id, $i, $i + $interval);
        my ($count) = $sth->fetchrow;

        push(@post_count, {count => $count, time => $i + $interval});
        print("$i/$stop_time $count\n");
    }

    return \@post_count;
}

sub get_popular_subjects_list {
    my $self = shift;
    my $limit = shift || 10;

    my $sth = $self->{dbh}->prepare("SELECT COUNT(`subject`),`subject` FROM `posts`
                                     WHERE `subject` != \"\"
                                     GROUP BY `subject` ORDER BY COUNT(`subject`) DESC
                                     LIMIT ?");

    $sth->execute($limit);

    my @subject_list = ();
    while(my ($count,$subject) = $sth->fetchrow) {
        push(@subject_list,{ count => $count, subject => $subject });
    }

    return \@subject_list;
}

sub get_popular_files_list {
    my $self = shift;
    my $limit = shift || 10;

    my $sth = $self->{dbh}->prepare("SELECT `file_id`,`path`,`md5` FROM `post_files`
                                     JOIN `files` USING(`file_id`)
                                     GROUP BY `file_id` ORDER BY COUNT(`file_id`) DESC
                                     LIMIT ?");

    $sth->execute($limit);

    my @popular_file_list = ();
    while(my ($file_id,$path,$md5) = $sth->fetchrow) {
        push(@popular_file_list, {
                                  file_id => $file_id,
                                  path => $path,
                                  md5 => $md5
        });
    }

    return \@popular_file_list;
}

sub get_first_post_time_by_board_id {
    my $self = shift;
    my $board_id = shift || croak("need board_id");

    my $sth = $self->{dbh}->prepare("SELECT strftime(\"%s\",`date`) FROM `posts`
                                     WHERE `board_id` = ? ORDER BY `post_id`
                                     LIMIT 1");

    $sth->execute($board_id);

    if(my ($time) = $sth->fetchrow) {
        return $time;
    } else {
        return undef;
    }
}

sub get_text_length_by_board_id {
    my $self = shift;
    my $board_id = shift || croak("need board_id");

    my $sth = $self->{dbh}->prepare("SELECT length(group_concat(`text`,\"\")) FROM `posts`
                                     WHERE `board_id` = ?");
    $sth->execute($board_id);

    if(my ($text_length) = $sth->fetchrow) {
        return $text_length
    } else {
        return undef;
    }
}

sub get_total_files {
    my $self = shift;

    my $sth = $self->{dbh}->prepare("SELECT COUNT(*) FROM `files`");

    $sth->execute();
    my ($count) = $sth->fetchrow;

    return $count;
}

sub get_total_posts_by_board_id {
    my $self = shift;
    my $board_id = shift || croak("need board id");

    my $sth = $self->{dbh}->prepare("SELECT COUNT(*) FROM `posts`
                                     WHERE `board_id` = ?");
    
    $sth->execute($board_id);
    if(my ($post_count) = $sth->fetchrow) {
        return $post_count;
    } else {
        return undef;
    }
}

sub get_total_posts {
    my $self = shift;
    my $thread_id = shift || undef;

    my $sth;
    if($thread_id) {
        $sth = $self->{dbh}->prepare("SELECT COUNT(*) FROM `posts`
                                      WHERE `thread_id` = ?");
        $sth->execute($thread_id);
    } else {
        $sth = $self->{dbh}->prepare("SELECT COUNT(*) FROM `posts`");
        $sth->execute();
    }

    my ($count) = $sth->fetchrow;

    return $count;
}

sub get_total_threads {
    my $self = shift;
    my $board_id = shift;

    my $sth;
    if($board_id) {
        $sth = $self->{dbh}->prepare("SELECT COUNT(DISTINCT `thread_id`) FROM `posts` WHERE `board_id` = ?");
        $sth->execute($board_id);
    } else {
        $sth = $self->{dbh}->prepare("SELECT COUNT(DISTINCT `thread_id`) FROM `posts`");
        $sth->execute;
    }

    my ($count) = $sth->fetchrow;

    return $count;
}

sub get_current_time {
    my $self = shift;

    my $sth = $self->{dbh}->prepare("SELECT strftime(\"%s\",\"now\")");

    $sth->execute();

    my ($time) = $sth->fetchrow;

    return $time;
}

sub delete_file {
    my $self = shift;
    my $file_id = shift || croak("gibe file_id");
    
    my $sth = $self->{dbh}->prepare("DELETE FROM `files` WHERE `file_id` = ?");
    if ($sth->execute($file_id)) {
        $self->{dbh}->commit;
        return 1;
    }
    return 0;
}


sub delete_tag {
    my $self = shift;
    my $tag_id = shift || croak("need tag_id");
    my $file_id = shift || croak("need file_id");

    my $sth = $self->{dbh}->prepare("DELETE FROM `file_tags`
                                     WHERE EXISTS (SELECT * FROM `tags`
                                                   WHERE `file_tags`.`tag_id` = `tags`.`tag_id`
                                                   AND `tag_id` = ?
                                                   AND `file_id` = ?)");

    $sth->execute($tag_id,$file_id);
    $self->{dbh}->commit;
}

sub setup {
    my $self = shift;
    my $dbh = $self->{dbh};

    $dbh->do("CREATE TABLE 
              IF NOT EXISTS `boards` (`board_id` INTEGER PRIMARY KEY NOT NULL,
                                      `board` VARCHAR(4) UNIQUE NOT NULL)");
                                      
    $dbh->do("CREATE TABLE
              IF NOT EXISTS `threads` (`board_id` INTEGER,
                                       `thread_id` INTEGER,
                                       `content_length` INTEGER,
                                        PRIMARY KEY(`board_id`,`thread_id`),
                                        FOREIGN KEY(`board_id`) REFERENCES `boards`(`board_id`)
                                        ON DELETE CASCADE ON UPDATE CASCADE)");

    $dbh->do("CREATE TABLE
              IF NOT EXISTS `posts` (`posts_rowid` INTEGER PRIMARY KEY,
                                     `board_id` INTEGER NOT NULL,
                                     `thread_id` INTEGER NOT NULL,
                                     `post_id` INTEGER NOT NULL,
                                     `subject` TEXT,
                                     `user` TEXT,
                                     `date` TEXT,
                                     `text` TEXT,
                                      UNIQUE(`board_id`,`post_id`),
                                      FOREIGN KEY(`board_id`) REFERENCES `boards`(`board_id`)
                                      ON DELETE CASCADE ON UPDATE CASCADE,
                                      FOREIGN KEY(`thread_id`) REFERENCES `threads`(`thread_id`)
                                      ON DELETE CASCADE ON UPDATE CASCADE)");

    

    $dbh->do("CREATE TABLE
              IF NOT EXISTS `files` (`file_id` INTEGER PRIMARY KEY,
                                     `path` TEXT UNIQUE NOT NULL,
                                     `timestamp` INTEGER NOT NULL,
                                     `md5` VARCHAR(32) UNIQUE NOT NULL)");

    $dbh->do("CREATE TABLE
              IF NOT EXISTS `post_files` (`file_id` INTEGER,
                                          `posts_rowid` INTEGER,
                                          `filename` TEXT,
                                           PRIMARY KEY(`file_id`,`posts_rowid`),
                                           FOREIGN KEY(`file_id`) REFERENCES `files`(`file_id`)
                                           ON DELETE CASCADE ON UPDATE CASCADE,
                                           FOREIGN KEY(`posts_rowid`) REFERENCES `posts`(`posts_rowid`)
                                           ON DELETE CASCADE ON UPDATE CASCADE)");

    $dbh->do("CREATE TABLE
              IF NOT EXISTS `tags` (`tag_id` INTEGER PRIMARY KEY,
                                    `tag` TEXT UNIQUE NOT NULL)");

    $dbh->do("CREATE TABLE
              IF NOT EXISTS `file_tags` (`tag_id` INTEGER NOT NULL,
                                         `file_id` INTEGER NOT NULL,
                                          PRIMARY KEY(`tag_id`,`file_id`),
                                          FOREIGN KEY(`tag_id`) REFERENCES `tags`(`tag_id`)
                                          ON DELETE CASCADE ON UPDATE CASCADE,
                                          FOREIGN KEY(`file_id`) REFERENCES `files`(`file_id`)
                                          ON DELETE CASCADE ON UPDATE CASCADE)");

    $dbh->do("CREATE TRIGGER
              IF NOT EXISTS `file_tags_delete` AFTER DELETE ON `file_tags`
              BEGIN
                  DELETE FROM `tags`
                  WHERE NOT EXISTS (SELECT * FROM `file_tags`
                                    WHERE `tags`.`tag_id` = `file_tags`.`tag_id`);
              END");

    $dbh->do("CREATE TRIGGER
              IF NOT EXISTS `post_files_delete` AFTER DELETE ON `post_files`
              BEGIN
                  DELETE FROM `files`
                  WHERE NOT EXISTS (SELECT * FROM `post_files`
                                    WHERE `files`.file_id = `post_files`.`file_id`);
              END");
             
    $dbh->do("CREATE TRIGGER
              IF NOT EXISTS `files_delete` AFTER DELETE ON `files`
              BEGIN
                  DELETE FROM `post_files`
                  WHERE `post_files`.`file_id` = OLD.`file_id`;
              END;");

    $dbh->do("CREATE INDEX IF NOT EXISTS `posts_index` ON `posts` (`board_id`,`thread_id`,`post_id`,`date`)");

    $dbh->do("CREATE INDEX IF NOT EXISTS `post_files_index` ON `post_files` (`filename`)");

    $dbh->commit;
}

sub _new_array {
    my $self = shift;
    my @array;
    return \@array;
}

sub DESTROY {
    my $self = shift;

    $self->{dbh}->disconnect;
}
1;
