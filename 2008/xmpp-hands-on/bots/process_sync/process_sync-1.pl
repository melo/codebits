#!/usr/bin/env perl

package ProcessSync;

use strict;
use warnings;
use base 'Bot';


package main;

use strict;
use warnings;

my $bot = ProcessSync->new(
  jid      => 'sync1@test.simplicidade.org',
  password => 'teste',
  host     => '127.0.0.1',
  port     => 5222,
  
  http_port => 3005,
);
$bot->start;


ProcessSync->run;

