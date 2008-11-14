package Net::XMPP2::IM::Message;
use strict;
use overload
  '""' => "to_string";

use Net::XMPP2::IM::Delayed;

our @ISA = qw/Net::XMPP2::IM::Delayed/;

=head1 NAME

Net::XMPP2::IM::Message - Instant message

=head1 SYNOPSIS

   use Net::XMPP2::IM::Message;

   my $con = Net::XMPP2::IM::Connection->new (...);

   Net::XMPP2::IM::Message->new (
      body => "Hello there!",
      to   => "elmex@jabber.org"
   )->send ($con);

=head1 DESCRIPTION

This module represents an instant message. It's mostly
a shortlived object and acts as wrapper object around the
XML stuff that is happening under the hood.

A L<Net::XMPP2::IM::Message> object overloads the stringification
operation. The string represenation of this object is the return
value of the C<any_body> method.

L<Net::XMPP2::IM::Message> is derived from L<Net::XMPP2::IM::Delayed>,
use the interface described there to find out whether this message was delayed.

=head1 METHODS

=over 4

=item B<new (%args)>

This method creates a new instance of a L<Net::XMPP2::IM::Message>.

C<%args> is the argument hash. All arguments to C<new> are optional.

These are the possible keys:

=over 4

=item connection => $connection

This is the L<Net::XMPP2::IM::Connection> object that will
be used to send this message when the C<send> method is called.

=item to => $jid

This is the destination JID of this message.
C<$jid> should be full if this message is send within a conversation
'context', for example when replying to a previous message.

Replies can also be generated by the C<make_reply> method, see also
the C<from> argument below.

=item from => $jid

This is the source JID of this message, it's mainly
used by the C<make_reply> method.

=item lang => $lang

This is the default language that will be used to tag the values
passed in the C<body> and C<subject> argument to C<new>.

=item body => $body

This is the text C<$body> of the message either with the language
tag from the C<lang> attached or without any language tag.

If you want to attach multiple bodies with different languages use the C<add_body>
method.

=item subject => $subject

This is the C<$subject> of the message either with the language
tag from the C<lang> attached or without any language tag.

If you want to attach the subject with a different language use the C<add_subject>
method.

=item type => $type

This field sets the type of the message. See also the L<type> method below.

The default value for C<$type> is 'normal'.

=back

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = bless { @_ }, $class;

   if (my $sub = delete $self->{subject}) {
      $self->add_subject ($sub);
   }
   if (my $body = delete $self->{body}) {
      $self->add_body ($body);
   }

   $self->{type} ||= 'normal'; # default it to 'normal'
   $self->{lang} ||= '';

   $self
}

sub from_node {
   my ($self, $node) = @_;

   $self->fetch_delay_from_node ($node);

   my $from     = $node->attr ('from');
   my $to       = $node->attr ('to');
   my $type     = $node->attr ('type');
   my ($thread) = $node->find_all ([qw/client thread/]);

   my %bodies;
   my %subjects;

   $bodies{$_->attr ('lang') || ''} = $_->text
      for $node->find_all ([qw/client body/]);
   $subjects{$_->attr ('lang') || ''} = $_->text
      for $node->find_all ([qw/client subject/]);

   $self->{from}     = $from;
   $self->{to}       = $to;
   $self->{type}     = $type;
   $self->{thread}   = $thread;
   $self->{bodies}   = \%bodies;
   $self->{subjects} = \%subjects;
   $self->{node}     = $node;
}

sub node { return $_[0]{node} }

sub to_string {
   my ($self) = @_;
   $self->any_body
}

=item B<from ([$jid])>

This method returns the source JID of this message.
If C<$jid> is not undef it will replace the current
source address.

=cut

sub from {
   my ($self, $from) = @_;
   $self->{from} = $from if defined $from;
   $self->{from}
}

=item B<to ([$jid])>

This method returns the destination JID of this message.
If C<$jid> is not undef it will replace the current
destination address.

=cut

sub to {
   my ($self, $to) = @_;
   $self->{to} = $to if defined $to;
   $self->{to}
}

=item B<make_reply ([$msg])>

This method returns a new instance of L<Net::XMPP2::IM::Message>.
The destination address, connection and type of the returned message
object will be set.

If C<$msg> is defined and an instance of L<Net::XMPP2::IM::Message>
the destination address, connection and type of C<$msg> will be changed
and this method will not return a new instance of L<Net::XMPP2::IM::Message>.

=cut

sub make_reply {
   my ($self, $msg) = @_;

   unless ($msg) {
      $msg = $self->new ();
   }

   $msg->{connection} = $self->{connection};
   $msg->to ($self->from);
   $msg->type ($self->type);

   $msg
}

=item B<is_connected ()>

This method returns 1 when the message is "connected".
That means: It returns 1 when you can call the C<send> method
without a connection argument. (It will also return only 1 when
the connection that is referenced by this message is still
connected).

=cut

sub is_connected {
   my ($self) = @_;
   $self->{connection}->is_connected
}

=item B<send ([$connection])>

This method send this message. If C<$connection>
is defined it will set the connection of this
message object before it is send.

=cut

sub send {
   my ($self, $connection) = @_;

   $self->{connection} = $connection if $connection;

   my @add;
   push @add, (subject => $self->{subjects})
      if %{$self->{subjects} || {}};
   push @add, (thread => $self->thread)
      if $self->thread;

   $self->{connection}->send_message (
      $self->to, $self->type, $self->{create_cbs},
      body => $self->{bodies},
      @add
   );
}

=item B<type ([$type])>

This method returns the type of the message, which
is either undefined or one of the following values:

   'chat', 'error', 'groupchat', 'headline', 'normal'

If the C<$type> argument is defined it will set the type
of this message.

=cut

sub type {
   my ($self, $type) = @_;
   $self->{type} = $type
      if defined $type;
   $self->{type}
}

=item B<thread ([$thread])>

This method returns the thread id of this message,
which might be undefined.

If you want to set the threadid simply pass the C<$thread>
argument.

=cut

sub thread {
   my ($self, $thread) = @_;
   $self->{thread} = $thread
      if defined $thread;
   $self->{thread}
}

=item B<lang ([$lang])>

This returns the default language tag of this message,
which can be undefined.

To set the language tag pass the C<$lang> argument, which
should be the new default language tag.

If you do not want to specify any language pass the empty
string as language tag.

=cut

sub lang {
   my ($self, $lang) = @_;
   $self->{lang} = $lang
      if defined $lang;
   $self->{lang}
}

=item B<subject ([$lang])>

This method returns the subject of this message.
If the C<$lang> argument is defined a subject of that
language will be returned or undef.
If the C<$lang> argument is undefined this method will
return either the subject in the default language.

=cut

sub subject {
   my ($self, $lang) = @_;

   if (defined $lang) {
      return $self->{subjects}->{$lang}
   }

   return $self->{subjects}->{$self->{lang}};

   undef
}

=item B<any_subject ([$lang])>

This method will try to find any subject on the message with the
following try order of languagetags:

  1. $lang argument if one passed
  2. default language
  3. subject without any language tag
  4. subject with the 'en' language tag
  5. any subject from any language

=cut

sub any_subject {
   my ($self, $lang) = @_;
   if (defined $lang) {
      return $self->{subjects}->{$lang}
         if defined $self->{subjects}->{$lang};
   }
   return $self->{subjects}->{$self->{lang}}
      if defined $self->{subjects}->{$self->{lang}};
   return $self->{subjects}->{''}
      if defined $self->{subjects}->{''};
   return $self->{subjects}->{en}
      if defined $self->{subjects}->{en};
   return $self->{subjects}->{$_} for (keys %{$self->{subjects}});
   return undef;
}

=item B<add_subject ($subject, [$lang], [$subject2, $lang2, ...])>

This method adds the subject C<$subject> with the optional
language tag C<$lang> to this message. If no C<$lang>
argument is passed the default language for this message will be used.

Further subject => lang pairs can passed to this function like this:

   $msg->add_subject ('foobar' => undef, "barfooo" => "de");

=cut

sub add_subject {
   my $self = shift;
   while (@_) {
      my $subj = shift;
      my $lang = shift;
      $self->{subjects}->{$lang || $self->{lang} || ''} = $subj;
   }
   $self
}

=item B<subjects>

This method returns a list of key value pairs
with the language tag as key and the subject as value.

The subject which has the empty string as key has no
language attached.

=cut

sub subjects {
   %{$_[0]->{subjects} || {}}
}

=item B<body ([$lang])>

This method returns the body of this message.
If the C<$lang> argument is defined a body of that
language will be returned or undef.
If the C<$lang> argument is undefined this method will
return either the body in the default language.

=cut

sub body {
   my ($self, $lang) = @_;

   if (defined $lang) {
      return $self->{bodies}->{$lang}
   } else {
      return $self->{bodies}->{$self->{lang}}
         if defined $self->{bodies}->{$self->{lang}};
   }

   undef
}

=item B<any_body ([$lang])>

This method will try to find any body on the message with the
following try order of languagetags:

  1. $lang argument if one passed
  2. default language
  3. body without any language tag
  4. body with the 'en' language tag
  5. any body from any language

=cut

sub any_body {
   my ($self, $lang) = @_;
   if (defined $lang) {
      return $self->{bodies}->{$lang}
         if defined $self->{bodies}->{$lang};
   }
   return $self->{bodies}->{$self->{lang}}
      if defined $self->{bodies}->{$self->{lang}};
   return $self->{bodies}->{''}
      if defined $self->{bodies}->{''};
   return $self->{bodies}->{en}
      if defined $self->{bodies}->{en};
   return $self->{bodies}->{$_} for (keys %{$self->{bodies}});
   return undef;
}

=item B<add_body ($body, [$lang], [$body2, $lang2, ...])>

This method adds the body C<$body> with the optional
language tag C<$lang> to this message. If no C<$lang>
argument is passed the default language for this message will be used.

Further body => lang pairs can passed to this function like this:

   $msg->add_body ('foobar' => undef, "barfooo" => "de");

=cut

sub add_body {
   my $self = shift;
   while (@_) {
      my $body = shift;
      my $lang = shift;
      $self->{bodies}->{$lang || $self->{lang} || ''} = $body;
   }
   $self
}

=item B<bodies>

This method returns a list of key value pairs
with the language tag as key and the body as value.

The body which has the empty string as key has no
language attached.

=cut

sub bodies {
   %{$_[0]->{bodies} || {}}
}

=item B<append_creation ($create_cb)>

This method allows the user to append custom XML stuff to the message
when it is sent. This is an example:

   my $msg =
      Net::XMPP2::IM::Message->new (
         body => "Test!",
         to => "test@test.tld",
      );
   $msg->append_creation (sub {
      my ($w) = @_;
      $w->startTag (['http://test.namespace','test']);
      $w->characters ("TEST");
      $w->endTag;
   });

   $msg->send ($con);

This should send a message stanza similar to this:

=cut

sub append_creation {
   my ($self, $cb) = @_;
   push @{$self->{create_cbs}}, $cb;
}

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2
