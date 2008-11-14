#!/usr/bin/env perl
# 
# Basic client
# 

use strict;
use warnings;
use Net::XMPP2::Client;
use AnyEvent::Mojo;

# Start a small bot
my $bot = Net::XMPP2::Client->new;
$bot->add_account('http2xmpp@test.simplicidade.org', 'teste', '127.0.0.1', 5222);
$bot->start;

# Start a HTTP server
my $server = mojo_server undef, 3001, sub {
  my (undef, $tx) = @_;
  my $req = $tx->req;
  my $url = $req->url;
  my $meth = $req->method;
  my $res = $tx->res;
  
  if ($url eq '/send' && $meth eq 'POST') {
    my $body = $req->param('body');
    my $to   = $req->param('to');
    return unless $body;
    
    $bot->send_message($body, $to, undef, 'chat');
  }
  else {
    $res->code(404);
    $res->body('These are not the droids you are looking for...');
    $res->headers->content_type('text/plain');
  }
};

$server->run;
