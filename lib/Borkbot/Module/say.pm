package Borkbot::Module::say;
use Moo;
use Borkbot::Module;

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  return 0 unless $self->is_control_channel($ev->to);

  if (my ($channel, $message) = $ev->msg =~ /^\.say\s+(#\w+)\s+(.*)/i) {
    unless ($self->in_channel($channel)) {
      $self->irc->privmsg($ev->reply_to, "I'm not on that channel.");
    } elsif ($message =~ s[^/me ][]) {
      $self->irc->action($channel, $message);
    } else {
      $self->irc->privmsg($channel, $message);
    }
    return 1;
  }

  return 0;
}

1;
