#!/usr/bin/env perl

package ProcessSync;

use strict;
use warnings;
use base 'Bot';


package main;

use strict;
use warnings;
use All;

my @bots = All->connect_all('ProcessSync');

ProcessSync->run;

