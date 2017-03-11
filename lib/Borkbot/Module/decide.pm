package Borkbot::Module::decide;
use Moo;
use Borkbot::Module;

use Text::ParseWords;

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  return 0 unless $ev->msg =~ /^\.decide\s+(.+)/i;

  my @choices = shellwords($1);

  if (@choices < 2) {
    $self->irc->privmsg($ev->reply_to, "Figure it out yourself!");
  } else {
    $self->irc->privmsg($ev->reply_to, "I choose: " . $choices[rand @choices]);
  }

  return 1;
}

1;
