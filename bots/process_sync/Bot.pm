package Bot;

use strict;
use warnings;
use base 'Mojo::Base';
use Net::XMPP2::Client;
use AnyEvent::Mojo;
use Encode 'decode';
use FindBin;
use lib "$FindBin::Bin/../../lib";

__PACKAGE__->attr([qw( jid password host port http_port http_host )]);
__PACKAGE__->attr([qw( bot http_server )]);
__PACKAGE__->attr([qw( stop_cond )]);
__PACKAGE__->attr('debug', default => sub { return $ENV{DEBUG} });

##################
# Start the circus

sub start {
  my $self = shift;
  
  $self->start_bot;
  $self->start_http_server;
  $self->started;
  
  return;
}

# Override started in your class if you want to do some more starting...
sub started {}

sub run {
  AnyEvent->condvar->recv; # event loop kicks in!
  
  return;
}


#########
# Our Bot

sub start_bot {
  my $self = shift;
  
  # Start a small bot
  my $bot = Net::XMPP2::Client->new(debug => $self->debug);
  $self->bot($bot);
  
  $bot->add_account($self->jid, $self->password, $self->host, $self->port);
  $bot->start;

  # When one account connects...
  $bot->reg_cb(
    connected                 => sub { return $self->bot_connected(@_)            },
    connect_error             => sub { return $self->bot_reconnect(@_)            },
    error                     => sub { return $self->bot_reconnect(@_)            },
    contact_request_subscribe => sub { return $self->bot_subscription_request(@_) },
    contact_subscribed        => sub { return $self->bot_contact_subscribed(@_)   },
  );

  $self->bot_started;
  
  return;
}

# Override to hook more stuff
sub bot_started {}

sub bot_connected {
  my ($self, $bot, $acc) = @_;

  print STDERR "Connected ",$acc->jid,"\n";

  return;
}

sub bot_reconnect {
  my ($self, $bot) = @_;
  
  my $t; $t = AnyEvent->timer(
    after => .5,
    cb => sub {
      $bot->update_connections;
      undef $t;
    }
  );
  
  return;
}

sub bot_subscription_request {
  my ($self, $bot, $acc, $roster, $contact) = @_;
  
  $contact->send_subscribed;
  $contact->send_subscribe;
  
  return;
}

sub bot_contact_subscribed {
  my ($self, $bot, $acc, $roster, $contact) = @_;

  $bot->send_message('Welcome!', $contact->jid, undef, 'chat');

  return;
}


#############
# HTTP server

sub start_http_server {
  my $self = shift;
  
  return unless $self->http_port;
  
  my $server = mojo_server $self->http_host, $self->http_port, sub {
    return $self->handle_http_request(@_);
  };
  $self->http_server($server);
  
  return;  
}

sub handle_http_request {
  my $self = shift;
  
  $self->http_404_response(@_);
  
  return;
}

sub http_404_response {
  my ($self, $tx) = @_;
  my $res = $tx->res;

  $res->code(404);
  $res->body('These are not the droids you are looking for...');
  $res->headers->content_type('text/plain');

  return;
}

1;
