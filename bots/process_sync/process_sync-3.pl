#!/usr/bin/env perl
#
# Add MUC, DISCO, and join a chatroom
# 
# uncomment feature
# 

package ProcessSync;

use strict;
use warnings;
use base 'Bot';
use Net::XMPP2::Ext::Disco;
use Net::XMPP2::Ext::MUC;
use Net::XMPP2::Util qw( split_jid );

__PACKAGE__->attr('sync_chatroom', default => 'sync@conference.test.simplicidade.org');
__PACKAGE__->attr([qw( disco_ext muc_ext )]);

sub bot_started {
  my ($self, $bot) = @_;
  
  # DISCO, a good XMPP citizen
  my $disco = Net::XMPP2::Ext::Disco->new;
  $self->disco_ext($disco);
  $bot->add_extension($disco);
  $disco->set_identity('client', 'bot', 'Sync process bot');
  # $disco->enable_feature('org.simplicidade.codebits_broadcaster');
  
  # Make sure we support MUC
  my $muc = Net::XMPP2::Ext::MUC->new( disco => $disco );
  $self->muc_ext($muc);
  $bot->add_extension($muc);
  
  # Auto-Connect to room
  $bot->reg_cb('after_connected', sub {
    my ($bot, $acc) = @_;
    
    return unless $self->sync_chatroom;
    
    my ($nick) = split_jid($acc->jid);
    $nick .= '-0';
    print STDERR "Joining room ", $self->sync_chatroom, " with nick '$nick'\n";
    
    $muc->join_room($self->sync_chatroom, $nick, sub {
      my ($room, $user, $error) = @_;
    
      if ($room) {
        print STDERR 'Bot ', $acc->jid, ' joined room "', $room->jid, '" with nick "', $user->nick,'"', "\n";
        $room->reg_cb('message', sub {
          my ($self, $msg, $is_echo) = @_;
          return if $is_echo;
          
          return if $msg->is_delayed;
          
          my $body = $msg->body;
          return unless $body;
          
          return unless $body =~ m/^dudes[,:]\s*(.+)/;
          
          my $command = $1;
          return unless $command;
          
          my $reply = $msg->make_reply;
          $reply->add_body("Yo, mike! No can do '$command'");
          $reply->send;
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



package main;

use strict;
use warnings;
use All;

my @bots = All->connect_all('ProcessSync');

ProcessSync->run;

