#!/usr/bin/perl

use strict;
use warnings;

package _index;

sub content {
    require "view/__head.pm";
    require "view/__foot.pm";

    my $vars = shift;

    __head::content();
    print "$vars->{menu}";
    __foot::content();
}
1;
