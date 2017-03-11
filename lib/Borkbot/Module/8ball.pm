package Borkbot::Module::8ball;
use Moo;
use Borkbot::Module;

my @eightball_quotes = (
  "No.",
  "Yes.",
  "Maybe.",
  "Results uncertain.  Try again later.",
  "Reply hazy, try again.",
  "Outlook not good.",
  "All signs point to yes.",

  "Outlook not good.  Try pine or mutt.",
  "Corner pocket.",
  "Side pocket.",
  "Scratch.",
  "Take 1 bottle of vodka and call me in the morning.",
  "How the hell should I know?",
  "Hahahahahaha.  What a dumb question.  No.",
  "I'm in a bad mood, go away.",
  "I slept with your SO.",

  "Doubtful.",
  "It is certain.",
  "All signs point to no.",
  "Outlook good.",
  "My sources say no.",
  "My sources say yes.",
  "Go ask TimeFysh.",
  "Better not tell you now.",
  "Don't count on it.",
  "You may rely on it.",
);

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  return 0 unless $ev->msg =~ /^\.8ball\s+/i;

  my $response;

  if ($ev->msg =~ /^.8ball who's your daddy\??/i) {
    $response = 'I have two daddies, beez and hobbs.';
  } else {
    $response = $eightball_quotes[rand @eightball_quotes];
  }

  $self->irc->privmsg($ev->{reply_to}, "[8ball] $response");
  return 1;
}

1;
