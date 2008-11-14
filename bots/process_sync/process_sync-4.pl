#!/usr/bin/env perl
#
# Some commands...
# 

package ProcessSync;

use strict;
use warnings;
use base 'Bot2';
use AnyEvent;

__PACKAGE__->attr('tasks', default => sub { return {} });

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
  elsif ($cmd =~ m/^\s*yo\s*[?!]?\s*$/i) {
    $reply = $msg->make_reply;
    $reply->add_body("#anita Rules!");
  }
  elsif ($cmd =~ m/^\s*ftw\s*[?!]?\s*$/i) {
    $reply = $msg->make_reply;
    $reply->add_body("#anita FTW!");
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
  elsif ($cmd =~ m/^\s*for\s+(\S+)\s+do\s+(.+)/) {
    my ($task_id, $cmd) = ($1, $2);
    my $ok = $self->do_thy_master_bidding($room, $task_id, $cmd);
    
    $reply = $msg->make_reply;
    if ($ok) {
      $reply->add_body(qq{By you command, named $task_id, I shall do $cmd});
      $reply->append_creation(sub {
        _exml($task_id);
        _exml($cmd);
        $_[0]->raw(qq{<task xmlns='org.simplicidade.just-do-it' id='$task_id'><command>$cmd</command></task>});
      });
    }
    else {
      $reply->add_body("Master please, I'm already doing '$task_id', I beg of you, give me thy patience");
    }
  }
  
  if ($reply) {
    my $t; $t = AnyEvent->timer(
      after => (int(rand(5)) / 10),
      cb    => sub { $reply->send; undef $t },
    );
    # $reply->send; # To fast! ;)
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

sub do_thy_master_bidding {
  my ($self, $room, $task_id, $cmd) = @_;
  my $tasks = $self->tasks;
  
  return if exists $tasks->{$task_id};

  my $claim = int(rand(10000));
  my %task = (
    id     => $task_id,
    cmd    => $cmd,
    claim  => $claim,
    others => {},
  );

  # Catch everybody else commands
  $task{listener} = $self->reg_ns_trigger('org.simplicidade.just-do-it' => sub {
    my ($bot, $room, $msg, $node, $trg) = @_;
    
    # Ignore if not for my ID
    return unless $node->attr('id') eq $task_id;
    
    # Ignore me
    my $other_user = $room->get_user_jid($msg->from);
    my $other_nick = $other_user->nick;
    return if $room->get_me->nick eq $other_nick;
    
    # Fetch the message payload, first child is enough
    my $payload = ($node->nodes)[0];
    my $name = $payload->name;
    
    if ($name eq 'claim') {
      $task{others}{$other_nick} = $payload->text;
    }
    elsif ($name eq 'done') {
      if ($task{predecessor} && $task{predecessor} eq $other_nick) {
        $self->_do_task($room, \%task);
      }
    }
  });
  
  # Explain why this timer is very important...
  # hmms... wtf, why is this thing important...?
  # where are my notes?!
  $task{runner} = AnyEvent->timer(
    after => 1,
    cb => sub {
      # Send our claim
      my $msg = $room->make_message;
      $msg->add_body("My claim to the top dog is: $claim");
      $msg->append_creation(sub {
        $_[0]->raw(qq{<task xmlns='org.simplicidade.just-do-it' id='$task_id'><claim>$claim</claim></task>});
      });
      $msg->send;
      
      # Close the vote and do it
      $task{runner} = AnyEvent->timer(
        after => 2,
        cb    => sub {
          my $my_nick = $room->get_me->nick;
          
          my @claims = ([$claim, $my_nick]);
          while (my ($nick, $claim) = each %{$task{others}}) {
            push @claims, [$claim, $nick];
          }
          
          # Order by claim desc, then by nick
          @claims = sort { $b->[0] <=> $a->[0] || $a->[1] cmp $b->[1] } @claims;
          
          # I'm the top dog?
          if ($claims[0][1] eq $my_nick) {
            $task{runner} = AnyEvent->timer(
              after => 1,
              cb => sub {
                $self->_do_task($room, \%task);
              },
            );
            
            # Gloat!
            my $gloat_msg = $room->make_message;
            $gloat_msg->add_body("Ezekiel 25:17, bitches... I'm the top dog!");
            $gloat_msg->append_creation(sub {
              my $w = shift;
              my $new_world_order = '';
              foreach my $claim (@claims) {
                _exml($claim->[1]);
                $new_world_order .= qq{<nick>$claim->[1]</nick>};
              }
              $w->raw(qq{
                <task xmlns='org.simplicidade.just-do-it' id='$task_id'>
                  <topdog claim='$claims[0][0]'>
                    <new_world_order>$new_world_order</new_world_order>
                  </topdog>
                </task>
              });
            });
            $gloat_msg->send;
          }
          else {
            # Find our predecessor
            # we should parse the list the top dog gaves us...
            # but I'm a lazy bastard...
            my $pred;
            my $delay;
            foreach my $claim (@claims) {
              $delay++;
              last if $claim->[1] eq $my_nick;
              $pred = $claim->[1];
            }
            $task{predecessor} = $pred;
            
            # bow before the predecessor, in order
            $task{runner} = AnyEvent->timer(
              after => $delay * .1,
              cb    => sub {
                my $bow_msg = $room->make_message;
                $bow_msg->add_body("Mercy, please... I bow before thee, oh great $pred");
                $bow_msg->append_creation(sub {
                  _exml($pred);
                  $_[0]->raw(qq{<task xmlns='org.simplicidade.just-do-it' id='$task_id'><bow>$pred</bow></task>});
                });
                $bow_msg->send;
                
                # We will wait for the predecessor so we no longer need the runner
                delete $task{runner};
              },
            );
          }
        },
      );
    },
  );
  
  $tasks->{$task_id} = \%task;
  
  return $task_id;
}

sub _do_task {
  my ($self, $room, $task) = @_;
  
  $task->{runner} = AnyEvent->timer(
    after => 1,
    cb    => sub {
      my $do_msg = $room->make_message;
      $do_msg->add_body("Yay! My turn to do '$task->{cmd}'... Oh, so nice...");
      $do_msg->append_creation(sub {
        $_[0]->raw(qq{<task xmlns='org.simplicidade.just-do-it' id='$task->{id}'><done /></task>});
      });
      $do_msg->send;

      # Finally done, cleanup
      my $tasks = $self->tasks;
      delete $tasks->{$task->{id}};
      $self->unreg_ns_trigger($task->{listener});
      %$task = ();
    }
  );
  
  
  
  # Task is done, clean it up...
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

