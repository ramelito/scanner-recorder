#!/usr/bin/perl -w

@items = split("/", $ARGV[0]);
for ($i = 0; $i < @items; $i++) {
    if ($items[$i] =~ m/^usb[0-9]+$/) {
        $portno=$items[$i+2];
        $portno =~ s/-//g;
        $portno =~ s/\.//g;
        $portno =~ s/://g;
        print "$portno\n";
        last;
    }
}
