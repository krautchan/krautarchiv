#!/usr/bin/perl

use strict;
use warnings;

package Utilities;

use Carp qw( croak );
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
