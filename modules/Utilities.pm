#!/usr/bin/perl

use strict;
use warnings;

package Utilities;

use Carp qw( croak );
use File::Path qw(make_path);
use Image::Imlib2;

sub create_file_link {
    my $file_id = shift || croak("need file_id");
    my $path = shift || croak("need path");
    my $file_folder = shift || croak("need file_folder");
    my $thumb_folder = shift || croak("need thumb_folder");

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
        my $thumbnail = create_thumbnail($path,$file_folder,$thumb_folder);
        return "<a href=?view=show_file&file_id=$file_id><img src=$thumbnail width=200 /></a>";
    }
}

sub create_thumbnail {
    my $path = shift || croak("need path");
    my $file_folder = shift || croak("need file_folder");
    my $thumb_folder = shift || croak("need thumb_folder");

    my @path = split(/\//,$path);
    my $filename = pop(@path);

    my $thumbpath = $thumb_folder;
    foreach(@path) {
        $thumbpath .= "/$_";
    }

    unless( -e $thumbpath) {
        make_path($thumbpath);
    }

    $thumbpath .= "/$filename";

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

sub create_graph {
    my $board = shift;
    my $file_folder = shift;
    my $data_folder = shift;
    
    my $last = `rrdtool last $data_folder/$board.rrd`;
    $last =~ s/\s//g;

    `rrdtool graph $file_folder/${board}_day.svg -a SVG -t "/${board}/ Posts/Day" \\
     --dynamic-labels --full-size-mode -w 1030 -h 300 -X 0 -i --disable-rrdtool-tag \\
     -W "Krautarchiv - Das Archiv für den Bernd von Welt" \\
     -v "Posts/5 Min" \\
     --alt-y-grid --end $last --start end-1d \\
     --x-grid MINUTE:10:HOUR:1:MINUTE:120:0:%R \\
     -c BACK#AAAACC -c CANVAS#EEEEEE -c SHADEA#EEEEEE -c SHADEB#EEEEEE --border 3 --font DEFAULT:0:Helvetica-Bold \\
     DEF:p=$data_folder/$board.rrd:posts:AVERAGE \\
     VDEF:avg=p,AVERAGE \\
     VDEF:min=p,MINIMUM \\
     VDEF:max=p,MAXIMUM \\
     AREA:p#665C00CC:"Posts\\l" \\
     COMMENT:"\\u" \\
     GPRINT:min:"Minimum %4.2lf Posts\\r" \\
     GPRINT:avg:"Average %4.2lf Posts\\r" \\
     GPRINT:max:"Maximum %4.2lf Posts\\r" &> /dev/null`;

    `rrdtool graph $file_folder/${board}_week.svg -a SVG -t "/${board}/ Posts/Week" \\
     --dynamic-labels --full-size-mode -w 1030 -h 300 -X 0 -i --disable-rrdtool-tag \\
     -W "Krautarchiv - Das Archiv für den Bernd von Welt" \\
     -v "Posts/5 Min" \\
     --alt-y-grid --end $last --start end-1w \\
     -c BACK#AAAACC -c CANVAS#EEEEEE -c SHADEA#EEEEEE -c SHADEB#EEEEEE --border 3 --font DEFAULT:0:Helvetica-Bold \\
     DEF:p=$data_folder/$board.rrd:posts:AVERAGE \\
     VDEF:avg=p,AVERAGE \\
     VDEF:min=p,MINIMUM \\
     VDEF:max=p,MAXIMUM \\
     AREA:p#665C00CC:"Posts\\l" \\
     COMMENT:"\\u" \\
     GPRINT:min:"Minimum %4.2lf Posts\\r" \\
     GPRINT:avg:"Average %4.2lf Posts\\r" \\
     GPRINT:max:"Maximum %4.2lf Posts\\r" &> /dev/null`;

    `rrdtool graph $file_folder/${board}_month.svg -a SVG -t "/${board}/ Posts/Month" \\
     --dynamic-labels --full-size-mode -w 1030 -h 300 -X 0 -i --disable-rrdtool-tag \\
     -W "Krautarchiv - Das Archiv für den Bernd von Welt" \\
     -v "Posts/5 Min" \\
     --alt-y-grid --end $last --start end-1month \\
     -c BACK#AAAACC -c CANVAS#EEEEEE -c SHADEA#EEEEEE -c SHADEB#EEEEEE --border 3 --font DEFAULT:0:Helvetica-Bold \\
     DEF:p=$data_folder/$board.rrd:posts:AVERAGE \\
     VDEF:avg=p,AVERAGE \\
     VDEF:min=p,MINIMUM \\
     VDEF:max=p,MAXIMUM \\
     AREA:p#665C00CC:"Posts\\l" \\
     COMMENT:"\\u" \\
     GPRINT:min:"Minimum %4.2lf Posts\\r" \\
     GPRINT:avg:"Average %4.2lf Posts\\r" \\
     GPRINT:max:"Maximum %4.2lf Posts\\r" &> /dev/null`;

    `rrdtool graph $file_folder/${board}_year.svg -a SVG -t "/${board}/ Posts/Year" \\
     --dynamic-labels --full-size-mode -w 1030 -h 300 -X 0 -i --disable-rrdtool-tag \\
     -W "Krautarchiv - Das Archiv für den Bernd von Welt" \\
     -v "Posts/5 Min" \\
     --alt-y-grid --end $last --start end-1year \\
     -c BACK#AAAACC -c CANVAS#EEEEEE -c SHADEA#EEEEEE -c SHADEB#EEEEEE --border 3 --font DEFAULT:0:Helvetica-Bold \\
     DEF:p=$data_folder/$board.rrd:posts:AVERAGE \\
     VDEF:avg=p,AVERAGE \\
     VDEF:min=p,MINIMUM \\
     VDEF:max=p,MAXIMUM \\
     AREA:p#665C00CC:"Posts\\l" \\
     COMMENT:"\\u" \\
     GPRINT:min:"Minimum %4.2lf Posts\\r" \\
     GPRINT:avg:"Average %4.2lf Posts\\r" \\
     GPRINT:max:"Maximum %4.2lf Posts\\r" &> /dev/null`;
    
    return { day => "<img src=\"$file_folder/${board}_day.svg\" width=\"1030\" />",
             week => "<img src=\"$file_folder/${board}_week.svg\" width=\"1030\" />",
             month => "<img src=\"$file_folder/${board}_month.svg\" width=\"1030\" />",
             year => "<img src=\"$file_folder/${board}_year.svg\" width=\"1030\" />"
           }
}

sub format_bytes {
    my $number = shift || croak("need number");

    my @unit = ("Byte", "KB", "MB", "GB", "TB", "PB");

     my $count = 0;
     while($number > 1024) {
        $number = $number/1024;
        $count++;
     }
      
     return sprintf("%.2f",$number) . " $unit[$count]";
}
1;
