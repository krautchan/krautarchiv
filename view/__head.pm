#!/usr/bin/perl

package __head;

sub content {
    print "Content-Type: text/html\r\n\r\n";
    print "<html>\n";
    print "<head>\n";
    print "<title>Archive</title>\n";
    print "<link rel=\"stylesheet\" type=\"text/css\" href=\"css/style.css\">\n";
    print "</head>\n";
    print "<body>\n"
}
1;
