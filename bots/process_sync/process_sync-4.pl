#!/usr/bin/env perl
#
# Some commands...
# 

package ProcessSync;

use strict;
use warnings;
use base 'Bot2';
use AnyEvent;

__PACKAGE__->attr('streams', default => sub { return {} });
__PACKAGE__->attr('next_stream_id', default => 1);

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
  elsif ($cmd =~ m/^\s*stream\s+([\d.]+)\s+(\S+)/) {
    my ($interval, $arg) = ($1, $2);
    my $id = $self->stream_start($room, $1, $2);
    
    $reply = $msg->make_reply;
    # For the humans out there, with love...
    $reply->add_body("Starting stream $id, each $interval with arg $arg");
    
    $reply->append_creation(sub {
      _exml($arg);
      $_[0]->raw(qq{<s xmlns='org.simplicidade.stream'><interval>$interval</interval><arg>$arg</arg></s>});
    });
  }
  elsif ($cmd =~ m/^\s*stop stream\s+(\S+)/) {
    if (my $count = $self->stream_stop($room, $1)) {
      $reply = $msg->make_reply;
      $reply->add_body("Stopped $count streams");
    }
    else {
      $reply = $msg->make_reply;
      $reply->add_body("These streams are not the ones you are looking for...");
    }
  }
  
  if ($reply) {
    $reply->send;
  }
  else {
    $self->muc_handle_command_unknown($room, $msg, $cmd);
  }
}

sub stream_start {
  my ($self, $room, $interval, $arg) = @_;
  my $streams = $self->streams;

  my $id = $self->next_stream_id;
  $self->next_stream_id($id+1);
  
  my $t; $t = AnyEvent->timer(
    after => $interval,
    interval => $interval,
    cb => sub {
      my $v = $arg;
      $v = int(rand($v))+1 if $v =~ m/^\d+$/;

      my $msg = $room->make_message;
      $msg->add_body("[$id]: $v");
      $msg->append_creation(sub {
        _exml($v);
        $_[0]->raw(qq{<s xmlns='org.simplicidade.stream' id='$id'><item>$v</item></s>});
      });
      $msg->send;
    },
  );
  
  $streams->{$id} = $t;
  
  return $id;
}

sub stream_stop {
  my ($self, $room, $patt) = @_;
  my $streams = $self->streams;
  my @ids;
  
  if ($patt eq 'all') {
    @ids = keys %$streams;
  }
  elsif (exists $streams->{$patt}) {
    @ids = ($patt);
  }
  
  return unless @ids;
  
  foreach my $id (@ids) {
    delete $streams->{$id};
    
    my $msg = $room->make_message;
    $msg->add_body("Stoping stream $id");
    $msg->append_creation(sub {
      $_[0]->raw(qq{<s xmlns='org.simplicidade.stream' id='$id'><stop /></s>});
    });
    $msg->send;
  }
  
  return scalar(@ids);
}


sub _exml {
  $_[0] =~ s/&/&amp;/g;
  $_[0] =~ s/'/&quot;/g;
  $_[0] =~ s/</&lt;/g;
  $_[0] =~ s/>/&gt;/g;
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

