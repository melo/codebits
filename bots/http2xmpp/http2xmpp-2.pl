#!/usr/bin/env perl

use strict;
use warnings;
use Net::XMPP2::Client;
use AnyEvent::Mojo;
use Encode 'decode';

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
  
  if ($url eq '/send') {
    my $body = decode('utf8', $req->param('body') || '');
    my $to   = decode('utf8', $req->param('to')   || '');

    my $extra = '';
    if ($meth eq 'POST') {
  
      $bot->send_message($body, $to, undef, 'chat') if $body;
      $extra = '<p style="color: red;">Thank you sir, can I have another?</p>';
    }

    $to ||= 'melo@test.simplicidade.org';
    
    $res->code(200)->headers->content_type('text/html');
    $res->body(<<"    EOH")
      <html>
      <head>
         <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
         <title>Send a message!</title>
      </head>
      <body>
        <h1>Send a message</h1>
        $extra
        <form method="post" action="/send" accept-charset="utf-8">
          <label for="to">JID:</label><input type="text" name="to" id="to" value="$to" size="60"/><br />
          <label for="body">Body:</label><textarea name="body" id="body" cols="50" rows="4">$body</textarea><br />
          <input type="submit" value="Send!" />
        </form>
      </body>
    </html>
    EOH
  }
  else {
    $res->code(404);
    $res->body('These are not the droids you are looking for...');
    $res->headers->content_type('text/plain');
  }
};

$server->run;
