use strict;
use warnings;

package RRD;

use Carp qw( croak );

sub new {
    my $type = shift;
    my $db = shift || croak("Need database reference");
    my $graph_folder = shift || "img";

    my $class = ref $type || $type;

    my $self = { db => $db,
                 graph_folder => $graph_folder
               };
    bless $self, $class;

    return $self;
}

sub create_rrd_files {
    my $self = shift;
    my $board = shift || croak("Need board");

    my $board_id = $self->{db}->get_board_id($board) || die("unknown board: $board");
    my $last_update = $self->{db}->get_first_post_time_by_board_id($board_id);

    unless( -e "$board.rrd") {
        system("rrdtool create $board.rrd -b $last_update --step 300 ".
               "DS:posts:GAUGE:600:0:1000 ".
               "RRA:MAX:0.5:1:2016") || die("Error $?: Could not create $board.rrd");
    }

    unless( -e "$board-year.rrd") {
        system("rrdtool create $board-year.rrd -b $last_update --step 86400 ".
               "DS:posts:GAUGE:172800:0:1000000 ".
               "RRA:MAX:0.5:1:400") || die("Error $?: Could not create $board-year.rrd");
    }
}

sub update_rrd_files {
    my $self = shift;
    my $board = shift || croak("need board");

    my $board_id = $self->{db}->get_board_id($board) || die("unknown board: $board");
    my $now = $self->{db}->get_current_time();

    if( -e "$board.rrd") {
        my $last_update = `rrdtool last $board.rrd`;
        $last_update =~ s/\s//g;

        my $post_count = $self->{db}->get_post_count_by_time_interval($board_id,$last_update,$now,300);
        foreach(@{$post_count}) {
            print("Updating $board.rdd; Time: $_->{time}/$now $_->{count}\n");
            system("rrdtool update $board.rrd $_->{time}:$_->{count}") || 
                print("Error $?: Could not insert $_->{count} at time $_->{time}\n");
        }
    }

    if( -e "$board-year.rrd") {
         my $last_update = `rrdtool last $board-year.rrd`;
         $last_update =~ s/\s//g;

         my $post_count = $self->{db}->get_post_count_by_time_interval($board_id,$last_update,$now,86400);

         foreach(@{$post_count}) {
            print("Updating $board-year.rdd; Time: $_->{time}/$now $_->{count}\n");
            system("rrdtool update $board-year.rrd $_->{time}:$_->{count}") ||
                print("Error $?: Could not insert $_->{count} at time $_->{time}\n");
         }
    }
}

sub update_graphs {
    my $self = shift;

    my $board_list = $self->{db}->get_board_list();

    foreach(@$board_list) {
        if( -e "$_->{board}.rrd") {
            my $last_update = `rrdtool last $_->{board}.rrd`;
            $last_update =~ s/\s//g;
            
            system("rrdtool graph $self->{graph_folder}/$_->{board}_day.svg -a SVG -t \"/$_->{board}/ Posts/Day\" ".
                   "--dynamic-labels --full-size-mode -w 1030 -h 300 -X 0 -i --disable-rrdtool-tag ".
                   "-W \"Krautarchiv - Das Archiv für den Bernd von Welt\" ".
                   "-v \"Posts/5 Min\" ".
                   "--alt-y-grid --end $last_update --start end-1d ".
                   "--x-grid MINUTE:10:HOUR:1:MINUTE:120:0:%R ".
                   "-c BACK#AAAACC -c CANVAS#EEEEEE -c SHADEA#EEEEEE -c SHADEB#EEEEEE ".
                   "--border 3 --font DEFAULT:0:Helvetica-Bold ".
                   "DEF:p=$_->{board}.rrd:posts:AVERAGE ".
                   "VDEF:avg=p,AVERAGE ".
                   "VDEF:min=p,MINIMUM ".
                   "VDEF:max=p,MAXIMUM ".
                   "LINE:p#CC3333:\"Posts\\l\" ".
                   "COMMENT:\"\\u\" ".
                   "GPRINT:min:\"Minimum %5.0lf Posts\\r\" ".
                   "GPRINT:avg:\"Average %5.0lf Posts\\r\" ".
                   "GPRINT:max:\"Maximum %5.0lf Posts\\r\"") ||
                print("Error $?: Can't update $_->{board}_day.svg\n");

            system("rrdtool graph $self->{graph_folder}/$_->{board}_week.svg -a SVG -t \"/$_->{board}/ Posts/Week\" ".
                   "--dynamic-labels --full-size-mode -w 1030 -h 300 -X 0 -i --disable-rrdtool-tag ".
                   "-W \"Krautarchiv - Das Archiv für den Bernd von Welt\" ".
                   "-v \"Posts/5 Min\" ".
                   "--alt-y-grid --end $last_update --start end-1w ".
                   "-c BACK#AAAACC -c CANVAS#EEEEEE -c SHADEA#EEEEEE -c SHADEB#EEEEEE ".
                   "--border 3 --font DEFAULT:0:Helvetica-Bold ".
                   "DEF:p=$_->{board}.rrd:posts:AVERAGE ".
                   "VDEF:avg=p,AVERAGE ".
                   "VDEF:min=p,MINIMUM ".
                   "VDEF:max=p,MAXIMUM ".
                   "LINE:p#CC3333:\"Posts\\l\" ".
                   "COMMENT:\"\\u\" ".
                   "GPRINT:min:\"Minimum %5.0lf Posts\\r\" ".
                   "GPRINT:avg:\"Average %5.0lf Posts\\r\" ".
                   "GPRINT:max:\"Maximum %5.0lf Posts\\r\"") ||
                print("Error $?: Can't update $_->{board}_week.svg\n");

            system("rrdtool graph $self->{graph_folder}/$_->{board}_month.svg -a SVG -t \"/$_{board}/ Posts/Month\" ".
                   "--dynamic-labels --full-size-mode -w 1030 -h 300 -X 0 -i --disable-rrdtool-tag ".
                   "-W \"Krautarchiv - Das Archiv für den Bernd von Welt\" ".
                   "-v \"Posts/Day\" ".
                   "--alt-y-grid --end $last_update --start end-1month ".
                   "--x-grid HOUR:12:DAY:1:DAY:1:86400:%a ".
                   "-c BACK#AAAACC -c CANVAS#EEEEEE -c SHADEA#EEEEEE -c SHADEB#EEEEEE ".
                   "--border 3 --font DEFAULT:0:Helvetica-Bold ".
                   "DEF:p=$_->{board}-year.rrd:posts:AVERAGE ".
                   "VDEF:avg=p,AVERAGE ".
                   "VDEF:min=p,MINIMUM ".
                   "VDEF:max=p,MAXIMUM ".
                   "LINE:p#CC3333:\"Posts\\l\" ".
                   "COMMENT:\"\\u\" ".
                   "GPRINT:min:\"Minimum %5.0lf Posts\\r\" ".
                   "GPRINT:avg:\"Average %5.0lf Posts\\r\" ".
                   "GPRINT:max:\"Maximum %5.0lf Posts\\r\"") ||
                print("Error $?: Can't update $_->{board}_month.svg\n");

            system("rrdtool graph $self->{graph_folder}/$_->{board}_year.svg -a SVG -t \"/$_->{board}/ Posts/Year\" ".
                   "--dynamic-labels --full-size-mode -w 1030 -h 300 -X 0 -i --disable-rrdtool-tag ".
                   "-W \"Krautarchiv - Das Archiv für den Bernd von Welt\" ".
                   "-v \"Posts/Day\" ".
                   "--alt-y-grid --end $last_update --start end-1year ".
                   "-c BACK#AAAACC -c CANVAS#EEEEEE -c SHADEA#EEEEEE -c SHADEB#EEEEEE ".
                   "--border 3 --font DEFAULT:0:Helvetica-Bold ".
                   "DEF:p=$_->{board}-year.rrd:posts:AVERAGE ".
                   "VDEF:avg=p,AVERAGE ".
                   "VDEF:min=p,MINIMUM ".
                   "VDEF:max=p,MAXIMUM ".
                   "LINE:p#CC3333:\"Posts\\l\" ".
                   "COMMENT:\"\\u\" ".
                   "GPRINT:min:\"Minimum %5.0lf Posts\\r\" ".
                   "GPRINT:avg:\"Average %5.0lf Posts\\r\" ".
                   "GPRINT:max:\"Maximum %5.0lf Posts\\r\"") ||
                print("Error $?: Can't update $_->{board}_year.svg\n");
        }
    }
}
1;
