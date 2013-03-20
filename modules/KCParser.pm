#!/usr/bin/perl

package KCParser;

use strict;
use warnings;

use Carp qw(croak);
use HTML::TreeBuilder 5 -weak;

sub new {
	my $type = shift;
	my $content = shift;
	
	my $self = {};
	my $class = ref $type || $type;
	bless $self, $class;
	
	$self->_parse_content($content);

    return $self;
}

sub parse_thread {
	my $self = shift;

	my @postlist = ();
	my $classname = "file_thread";

	foreach((scalar($self->{tree}->look_down("_tag", "div", "class", "thread")), $self->{tree}->look_down("_tag", "td", "class", "postreply"))) {
		my $post = {};
		($post->{id}) = $_->look_down("_tag", "input")->attr("name") =~ /post_(\d*)/;
		$post->{subject} = $_->look_down("_tag", "span", "class", "postsubject")->as_text;
		$post->{name} = $_->look_down("_tag", "span", "class", "postername")->as_text;
		$post->{date} = $_->look_down("_tag", "span", "class", "postdate")->as_text;
		my $id = $post->{id};
		foreach($_->look_down("_tag", "p", "id", "post_text_$id")->content_list) {
			$post->{text} .= ref($_) ? $_->as_HTML : $_;
		}

		$post->{files} = [];
		foreach($_->look_down("_tag", "div", "class", "$classname")) {
			my $file = {};
			$file->{filename} = $_->look_down("_tag","span", "style", "display:none")->as_text;
			($file->{path}) = $_->look_down("_tag", "a", "target", "_blank")->attr("href") =~ /\/files\/(.*)/;
			push(@{$post->{files}}, $file);
		}
		$classname = "file_reply";

		push(@postlist, $post);
	}

	return \@postlist;	
}

sub parse_thread_ids {
	my $self = shift;

	my @ids = ();

	foreach($self->{tree}->look_down("_tag", "div", "class", "thread")) {
		push(@ids, $_->attr("id") =~ /thread_(\d*)/);
	}

	return \@ids;
}


sub set_content {
	my $self = shift;
	my $content = shift || croak("content needed");

	$self->_parse_content($content);
}

sub _parse_content {
	my $self = shift;
	my $content = shift;

	if(!$content) {
		$self->{tree} = undef;
	} else {
		$self->{tree} = HTML::TreeBuilder->new_from_content($content);
	}	
}
1;