package All;

use strict;
use warnings;

sub connect_all {
  my ($class, $bot_class) = @_;
  my @bots;
  
  for(my $n = 1; $n <= ($ENV{BOT_COUNT} || 5); $n++) {
    my $bot = $bot_class->new(
      jid      => "sync$n\@test.simplicidade.org",
      password => 'teste',
      host     => '127.0.0.1',
      port     => 5222,

      http_port => 3004 + $n,
    );
    $bot->start;
    
    push @bots, $bot;
  }
  
  return @bots;
}

1;
