#!/usr/bin/env perl

package DataSync;

use strict;
use warnings;
use base 'Bot2';
use Mojo::Template;

__PACKAGE__->attr('pending');

sub muc_message {
  my ($self, $room, $msg) = @_;
  my $body = $msg->body;

  return unless $body;
  
  if (my $pending = $self->pending) {
    if (ref($pending) eq 'CODE') {
      $self->pending(undef);
      $pending->($body);
    }
    else {
      $self->pending("$pending<hr />$body");
    }
  }
  else {
    $self->pending($body);
  }
}

sub handle_http_request {
  my ($self, $httpd, $tx) = @_;
  my $url = $tx->req->url;
  my $meth = $tx->req->method;
  
  print STDERR "HIT: $meth $url\n";
  if ($url eq '/') {
    $self->send_app($tx);
  }
  elsif ($url eq '/shout') {
    $self->shout($tx);
  }
  else {
    $self->http_404_response($tx);
  }
}

sub send_app {
  my ($self, $tx) = @_;
  my $nick = $self->jid;
  my $res = $tx->res;
  
  $res->code(200)->headers->content_type('text/html');
  
  my $mt = Mojo::Template->new;
  $res->body(
    $mt->render_file('app.html', {
      jid => $self->jid,
    })
  );
  
  return;
}

sub shout {
  my ($self, $tx) = @_;
  my $req = $tx->req;
  my $res = $tx->res;
  
  if ($req->method eq 'POST') {
    my $room = $self->muc_my_sync_room;
    print STDERR "SYNC ROOM: $room\n";
    return $self->http_404_response($tx) unless $room;
    
    my $content = $req->body;
    my $msg = $room->make_message;
    $msg->add_body($content);
    $msg->append_creation(sub {
      my $w = shift;
      $w->raw(qq{
        <html xmlns='http://jabber.org/protocol/xhtml-im'>
          <body xmlns='http://www.w3.org/1999/xhtml'>
            <p>$content</p>
          </body>
        </html>
      });
    });
    print STDERR "SENT MUC MESSAGE\n";
    $msg->send;

    _response_with($res, 'OK');
  }
  else {
    $res->headers->connection('close');
    my $shout = $self->pending;

    my $conn = $tx->connection;
    print STDERR "TX $self $tx $conn ",$tx->connection, "\n";
    print STDERR "     Pending: ",(defined $shout? $shout : '<undef>'),"\n\n";

    # Old connection didn't die!
    if (ref($shout) eq 'CODE') {
      print STDERR "TX pending is CODE, callback\n";
      $shout->('');
      $shout = undef;
    }
    
    if ($shout) {
      print STDERR "TX has pending to reply\n";
      _response_with($res, $shout);
      $self->pending(undef);
    }
    else { # Long pool
      print STDERR "TX long pool, pause, and prepare callback\n";
      my $resume_cb = $conn->pause;
      print STDERR "TX PAUSE $self $tx $conn ",$tx->connection, "\n";

      $self->pending(sub {
        my $data = shift;
        _response_with($res, $data);
        
        print STDERR "TX RESUME $self $tx $conn ",$tx->connection, "\n";
        $resume_cb->();
      });
    }
  }
}

sub _response_with {
  my ($res, $msg) = @_;
  
  $res->code(200)->headers->content_type('text/plain');
  $res->body($msg);
}



package main;

use strict;
use warnings;

my @bots;

for(my $n = 1; $n <= ($ENV{BOT_COUNT} || 3); $n++) {
  my $bot = DataSync->new(
    jid      => "sync$n\@test",
    password => 'teste',
    host     => $ENV{BOT_HOST} || '127.0.0.1',
    port     => 5222,

    http_port => 3004 + $n,

    bot_name       => 'My Data Sync bot',
    disco_features => [ 'org.simplicidade.codebits2008.dom-sync' ],
    sync_chatroom => 'sync@conference.test',
  );
  $bot->start;
  
  push @bots, $bot;
}

DataSync->run;

