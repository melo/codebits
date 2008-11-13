#!/usr/bin/env perl
#
# Some commands...
# 

package ProcessSync;

use strict;
use warnings;
use base 'Bot2';


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

