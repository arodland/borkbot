package Borkbot::Module::ddate;
use Moo;
use Borkbot::Module;
use Date::Discordian;

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  if ($ev->msg =~ /^\.ddate\b/i) {
    if ($ev->msg =~ /^\.ddate\s*$/i) {
      $self->irc->privmsg($ev->reply_to, Date::Discordian->new(epoch => time)->discordian);
    } elsif ($ev->msg =~ /^\.ddate\s+(\d+)\s+(\d+)\s+(\d+)\s*$/i) {
      $self->irc->privmsg($ev->reply_to, Date::Discordian->new(day => $1, month => $2, year => $3)->discordian);
    } else {
      $self->irc->privmsg($ev->reply_to, "Usage: .ddate [day month year]");
    }
    return 1;
  } else {
    return 0;
  }
}

1;
