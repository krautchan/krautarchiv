use strict;
use warnings;

package RRD;

use Carp qw( croak );

sub new {
    my $type = shift;
    my $db = shift || croak("Need database reference");
    my $graph_folder = shift || "../img";

    my $class = ref $type || $type;

    my $self = { db => $db,
                 graph_folder => $graph_folder
               };
    bless $self, $class;

    return $self;
}

sub update_rrd {
    my $self = shift;
    my $board = shift || croak("need board");

    my $board_id = $self->{db}->get_board_id($board) || die("unknown board: $board");
    my $now = $self->{db}->get_current_time();
    my $last_update = $self->{db}->get_last_rrd_time_by_board_id($board_id);
    
    my $post_count = $self->{db}->get_post_count_by_time_interval($board_id,$last_update,$now,300);
    foreach(@{$post_count}) {
        print("Updating $board; Time: $_->{time}/$now $_->{count}\n");
        $self->{db}->add_rrd_data($board_id, $_->{time}, $_->{count});
    }

    $last_update = $self->{db}->get_last_rrd_year_time_by_board_id($board_id);
    $last_update -= ($last_update % 86400);

    $post_count = $self->{db}->get_post_count_by_time_interval($board_id,$last_update,$now,86400);

    foreach(@{$post_count}) {
        print("Updating $board; Time: $_->{time}/$now $_->{count}\n");
        $self->{db}->add_rrd_year_data($board_id, $_->{time}, $_->{count});
    }

    $self->{db}->commit();
}

sub update_graphs {
    my $self = shift;
    #my $board_id = shift;

    my $board_list = $self->{db}->get_board_list();
    
    foreach(@$board_list) {
        my $last_update = $self->{db}->get_last_rrd_time_by_board_id($_->{board_id});
        my $ds_base = "sql//sqlite3/sqlite3_dbdir=./dbname=data.db/".
                      "/rrd/time/posts/board_id=$_->{board_id}";

        system("rrdtool graph $self->{graph_folder}/$_->{board}_day.svg -a SVG -t \"/$_->{board}/ Posts/Day\" ".
               "--dynamic-labels --full-size-mode -w 1030 -h 300 -X 0 -i --disable-rrdtool-tag ".
               "-W \"Krautarchiv - Das Archiv für den Bernd von Welt\" ".
               "-v \"Posts/5 Min\" ".
               "--alt-y-grid --end $last_update --start end-1d ".
               "--x-grid MINUTE:10:HOUR:1:MINUTE:120:0:%R ".
               "-c BACK#AAAACC -c CANVAS#EEEEEE -c SHADEA#EEEEEE -c SHADEB#EEEEEE ".
               "--border 3 --font DEFAULT:0:Helvetica-Bold ".
               "DEF:p=$ds_base:max:MAX ".
               "VDEF:avg=p,AVERAGE ".
               "VDEF:min=p,MINIMUM ".
               "VDEF:max=p,MAXIMUM ".
               "LINE:p#CC3333:\"Posts\\l\" ".
               "COMMENT:\"\\u\" ".
               "GPRINT:min:\"Minimum %5.0lf Posts\\r\" ".
               "GPRINT:avg:\"Average %5.0lf Posts\\r\" ".
               "GPRINT:max:\"Maximum %5.0lf Posts\\r\"") &&
                    print("Error $?: Can't update $_->{board}_day.svg\n");


        system("rrdtool graph $self->{graph_folder}/$_->{board}_week.svg -a SVG -t \"/$_->{board}/ Posts/Week\" ".
               "--dynamic-labels --full-size-mode -w 1030 -h 300 -X 0 -i --disable-rrdtool-tag ".
               "-W \"Krautarchiv - Das Archiv für den Bernd von Welt\" ".
               "-v \"Posts/5 Min\" ".
               "--alt-y-grid --end $last_update --start end-1w ".
               "-c BACK#AAAACC -c CANVAS#EEEEEE -c SHADEA#EEEEEE -c SHADEB#EEEEEE ".
               "--border 3 --font DEFAULT:0:Helvetica-Bold ".
               "DEF:p=$ds_base:max:MAX ".
               "VDEF:avg=p,AVERAGE ".
               "VDEF:min=p,MINIMUM ".
               "VDEF:max=p,MAXIMUM ".
               "LINE:p#CC3333:\"Posts\\l\" ".
               "COMMENT:\"\\u\" ".
               "GPRINT:min:\"Minimum %5.0lf Posts\\r\" ".
               "GPRINT:avg:\"Average %5.0lf Posts\\r\" ".
               "GPRINT:max:\"Maximum %5.0lf Posts\\r\"") &&
            print("Error $?: Can't update $_->{board}_week.svg\n");

        $ds_base = "sql//sqlite3/sqlite3_dbdir=./dbname=data.db/rrdminstepsize=86000/".
                   "/rrd_year/time/posts/board_id=$_->{board_id}";
        $last_update = $self->{db}->get_last_rrd_year_time_by_board_id($_->{board_id});

        system("rrdtool graph $self->{graph_folder}/$_->{board}_month.svg -a SVG -t \"/$_->{board}/ Posts/Month\" ".
               "--dynamic-labels --full-size-mode -w 1030 -h 300 -X 0 -i --disable-rrdtool-tag ".
               "-W \"Krautarchiv - Das Archiv für den Bernd von Welt\" ".
               "-v \"Posts/Day\" ".
               "--alt-y-grid --start end-1month ".
               #"--x-grid HOUR:12:DAY:1:DAY:1:86400:%a ".
               "-c BACK#AAAACC -c CANVAS#EEEEEE -c SHADEA#EEEEEE -c SHADEB#EEEEEE ".
               "--border 3 --font DEFAULT:0:Helvetica-Bold ".
               "DEF:p=$ds_base:avg:MAX ".
               "VDEF:avg=p,AVERAGE ".
               "VDEF:min=p,MINIMUM ".
               "VDEF:max=p,MAXIMUM ".
               "LINE:p#CC3333:\"Posts\\l\" ".
               "COMMENT:\"\\u\" ".
               "GPRINT:min:\"Minimum %5.0lf Posts\\r\" ".
               "GPRINT:avg:\"Average %5.0lf Posts\\r\" ".
               "GPRINT:max:\"Maximum %5.0lf Posts\\r\"") &&
            print("Error $?: Can't update $_->{board}_month.svg\n");


        system("rrdtool graph $self->{graph_folder}/$_->{board}_year.svg -a SVG -t \"/$_->{board}/ Posts/Year\" ".
               "--dynamic-labels --full-size-mode -w 1030 -h 300 -X 0 -i --disable-rrdtool-tag ".
               "-W \"Krautarchiv - Das Archiv für den Bernd von Welt\" ".
               "-v \"Posts/Day\" ".
               "--alt-y-grid --end $last_update --start end-1year ".
               "-c BACK#AAAACC -c CANVAS#EEEEEE -c SHADEA#EEEEEE -c SHADEB#EEEEEE ".
               "--border 3 --font DEFAULT:0:Helvetica-Bold ".
               "DEF:p=$ds_base:max:MAX ".
               "VDEF:avg=p,AVERAGE ".
               "VDEF:min=p,MINIMUM ".
               "VDEF:max=p,MAXIMUM ".
               "LINE:p#CC3333:\"Posts\\l\" ".
               "COMMENT:\"\\u\" ".
               "GPRINT:min:\"Minimum %5.0lf Posts\\r\" ".
               "GPRINT:avg:\"Average %5.0lf Posts\\r\" ".
               "GPRINT:max:\"Maximum %5.0lf Posts\\r\"") &&
            print("Error $?: Can't update $_->{board}_year.svg\n");
        }
    }

1;
