#!/usr/bin/env perl
#
# Some commands...
# 

package ProcessSync;

use strict;
use warnings;
use base 'Bot2';

sub muc_handle_command {
  my ($self, $room, $msg, $cmd) = @_;
  my $reply;
  
  if ($cmd =~ m/^\s*pid\s*[?!]?\s*$/i) {
    $reply = $msg->make_reply;
    $reply->add_body("My pid is $$.");
  }
  elsif ($cmd =~ m/^\s*yo\s*[?!]?\s*$/i) {
    $reply = $msg->make_reply;
    $reply->add_body("Yo-Yo-Ma Rules!");
  }
  
  if ($reply) {
    $reply->send;
  }
  else {
    $self->muc_handle_command_unknown($room, $msg, $cmd);
  }
}

package main;

use strict;
use warnings;
use All;

my @bots = All->connect_all('ProcessSync',
  bot_name => 'My Sync bot',
  disco_features => [ 'org.simplicidade.codebits2008.sync' ],
  sync_chatroom => 'sync@conference.test.simplicidade.org',
  command_trigger => 'dudes',
#  room_nick => 'sync00',
);

ProcessSync->run;

