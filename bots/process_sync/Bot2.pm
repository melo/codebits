package Bot2;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use base 'Mojo::Base';
use Net::XMPP2::Client;
use Net::XMPP2::Ext::Disco;
use Net::XMPP2::Ext::MUC;
use Net::XMPP2::Util qw( split_jid );
use AnyEvent::Mojo;
use Encode 'decode';

__PACKAGE__->attr([qw( jid password host port http_port http_host bot_name )]);
__PACKAGE__->attr([qw( bot http_server )]);
__PACKAGE__->attr([qw( stop_cond )]);
__PACKAGE__->attr([qw( disco_ext muc_ext )]);
__PACKAGE__->attr([qw( disco_features )], default => []);
__PACKAGE__->attr([qw( sync_chatroom room_nick command_trigger )]);

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

  $self->bot_load_extensions($bot);
  $self->bot_started($bot);
  
  return;
}

# Override to hook more stuff
sub bot_started {
  my ($self, $bot) = @_;
  
  # Auto-Connect to room
  $bot->reg_cb('after_connected', sub {
    my ($bot, $acc) = @_;
    
    return unless $self->sync_chatroom;
    
    my $nick = $self->room_nick;
    ($nick) = split_jid($acc->jid) unless $nick;
    
    print STDERR "Joining room ", $self->sync_chatroom, " with nick '$nick'\n";
    
    $self->muc_ext->join_room($self->sync_chatroom, $nick, sub {
      my ($room, $user, $error) = @_;
      
      if ($room) {
        my $f_nick = $user->nick;
        print STDERR 'Bot ', $acc->jid, ' joined room "', $room->jid, qq{" with nick "$f_nick"\n};
        
        $room->reg_cb('message', sub {
          my ($room, $msg, $is_echo) = @_;
          my $body = $msg->body;
          my $trigger = $self->command_trigger;
          
          if ($is_echo) {
            $self->muc_echo_message($room, $msg);
          }
          elsif ($msg->is_delayed) {
            $self->muc_history_message($msg);
          }
          elsif ($trigger && $body =~ m/^($trigger|$nick)[,;:!]?\s*(.+)/) {
            $self->muc_handle_command($room, $msg, $2);
          }
        });
      }
      else {
        print STDERR 'FAILED joining room ', $self->sync_chatroom, ', reason "', $error->type ,'"', "\n";
      }
    
      return;
    },
    nickcollision_cb => sub {
      my $collided_nick = shift;
      print STDERR "Oops, nick '$collided_nick' collided; ";
      $collided_nick++;
      print STDERR "trying this one now '$collided_nick'\n";
      return $collided_nick;
    });
  });

}

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

sub bot_load_extensions {
  my ($self, $bot) = @_;
  
  # DISCO, a good XMPP citizen
  my $disco = Net::XMPP2::Ext::Disco->new;
  $self->disco_ext($disco);
  $bot->add_extension($disco);
  $disco->set_identity('client', 'bot', $self->bot_name);
  if (my $feats = $self->disco_features) {
    foreach my $feat (@$feats) {
      $disco->enable_feature($feat);
    }
  }
  
  # Make sure we support MUC
  my $muc = Net::XMPP2::Ext::MUC->new( disco => $disco );
  $self->muc_ext($muc);
  $bot->add_extension($muc);
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

sub muc_echo_message {}

sub muc_history_message {}

sub muc_handle_command {
  my ($self, $room, $msg, $command) = @_;
 
  $self->muc_handle_command_unknown($room, $msg, $command);
}

sub muc_handle_command_unknown {
  my ($self, $room, $msg, $command) = @_;
  
  my $reply = $msg->make_reply;
  $reply->add_body("Yo, mike! No can do '$command'");
  $reply->send;
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
