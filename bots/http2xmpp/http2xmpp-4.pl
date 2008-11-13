#!/usr/bin/env perl
#
# Connected message, auto-accept subscriptions, welcome message
#

use strict;
use warnings;
use Net::XMPP2::Client;
use AnyEvent::Mojo;
use Encode 'decode';

# Start a small bot
my $bot = Net::XMPP2::Client->new(debug => $ENV{DEBUG});
$bot->add_account('http2xmpp@test.simplicidade.org', 'teste', '127.0.0.1', 5222);
$bot->start;

# When one account connects...
$bot->reg_cb('connected', sub {
  my (undef, $acc) = @_;

  print STDERR "Connected ",$acc->jid,"\n";

  return;
});

# When someone wants a piece of me...
$bot->reg_cb('contact_request_subscribe', sub {
  my (undef, $acc, $roster, $contact) = @_;
  
  $contact->send_subscribed;
  $contact->send_subscribe;

  return;
});

# When they have a piece of me...
$bot->reg_cb('contact_subscribed', sub {
  my ($bot, $acc, $roster, $contact) = @_;
  
  $bot->send_message('Welcome!', $contact->jid, undef, 'chat');
  
  return;
});


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
    my $xml  = decode('utf8', $req->param('xml')   || '');

    my $extra = '';
    if ($meth eq 'POST' && $body) {
      my $msg = Net::XMPP2::IM::Message->new(
          body => $body,
          to   => $to,
          type => 'chat',
      );
      $msg->append_creation(sub {
        my ($w) = @_;
        $w->raw($xml);
      }) if $xml;
      
      $bot->send_message($msg);
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
          <label for="xml">XML:</label><textarea name="xml" id="xml" cols="50" rows="4">$xml</textarea><br />
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
