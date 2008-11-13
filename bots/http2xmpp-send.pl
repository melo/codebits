#!/usr/bin/env perl

use strict;
use warnings;
use LWP::UserAgent;
use Getopt::Long;


my %cfg;
my $ok = GetOptions(\%cfg, "to=s", "body=s" );
usage() unless $ok;

binmode(\*STDIN, ':utf8');
unless ($cfg{to}) {
  print "Type the destination JID:\n" if -t \*STDIN;
  while (! $cfg{to}) {
    my $to = <>;
    chomp($to);
    $cfg{to} = $to;
  }
}

unless ($cfg{body}) {
  print "Type the message to send, CTRL-D to send, CTRL-C to abort\n" if -t \*STDIN;
  local $/;
  $cfg{body} = <>;
}

my $ua = LWP::UserAgent->new;
my $r = $ua->post('http://127.0.0.1:3001/send', \%cfg);


sub usage {
  print STDERR <<EOU;
Usage: http2xmpp-send.pl --to=JID --message=MESSAGE
EOU

  exit(1);
}