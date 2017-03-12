package Borkbot::Module::lart;
use Moo;
use Borkbot::Module;

has 'in_progress' => (
  is => 'rw',
  default => 0,
);

has [qw(channel larter target error_to anonymous reason)] => (
  is => 'rw',
);

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  if ($ev->visibility eq 'public') {
    if (my ($channel, $target) = $ev->msg =~ /^\.lart\s+(?:(\#\w+) )?([\w\.\-\#\|\[\]\{\}\\\^\/]+)/i) {
      $self->channel($channel // $ev->to);
      $self->larter($ev->nick);
      $self->target($target);
      $self->error_to($ev->to);
      $self->reason(undef);
      $self->anonymous(0);
    } elsif (($channel, $target, my $reason) = $ev->msg =~ /^\.anonlart\s+(?:(\#\w+) )?([\w\.\-\#\|\[\]\{\}\\\^\/]+)(?:\s+(.+))?/i) {
      unless ($self->is_control_channel($ev->to)) {
        log_warning { "unprivileged anonlart from " . $ev->from . " on " . $ev->to };
        return 1;
      }
      $self->channel($channel // $ev->to);
      $self->larter($ev->nick);
      $self->target($target);
      $self->error_to($ev->to);
      $self->reason($reason);
      $self->anonymous(1);
    } else {
      return 0;
    }
  } else { # private msg
    if (my ($channel, $target) = $ev->msg =~ /^\.lart\s+(\#\w+)\s+([\w\.\-\#\|\[\]\{\}\\\^\/]+)/i) {
      $self->channel($channel);
      $self->larter($ev->nick);
      $self->target($target);
      $self->error_to($ev->nick);
      $self->reason(undef);
      $self->anonymous(0);
    } else {
      return 0;
    }
  }

  # If we made it here, we responded to a request. Do some sanity checks...
  if (lc $self->target eq lc $self->irc->nick) {
    $self->irc->action($self->error_to, "LARTs " . $self->larter . " with a clue-by-four (no way I'm LARTing myself!)");
    return 1;
  } elsif (lc $self->target eq lc $self->larter && $self->anonymous) {
    $self->irc->action($self->error_to, "LARTs " . $self->larter . " with a clue-by-four (you asked for it!)");
    return 1;
  } elsif (! $self->in_channel($self->channel)) {
    $self->irc->privmsg($self->error_to, "I'm not in " . $self->channel . "!");
    return 1;
  }

  # And fire it off.
  $self->in_progress(1);
  $self->irc->write(NAMES => $self->channel);
}

sub on_irc_rpl_namreply {
  my ($self, $ev) = @_;

  return unless $self->in_progress;
  my @names = split " ", $ev->raw_args->[3];
  s/^[@%^+]// for @names;

  for my $name (@names) {
    if (lc $name eq lc $self->target) {
      if ($self->anonymous) {
        my $msg_send = "LARTs " . $self->target . " with a clue-by-four.";
        if ($self->reason) {
          $msg_send .= " (" . $self->reason . ")";
        }
        $self->irc->action($self->channel, $msg_send);
      } else {
        $self->irc->action($self->channel, "LARTs " . $self->target . " with a clue-by-four. (" . $self->larter . " made me!)");
      }
      $self->in_progress(0);
      last;
    }
  }
  return 0;
}

sub on_irc_rpl_endofnames {
  my ($self, $ev) = @_;

  return unless $self->in_progress;
  $self->irc->action($self->error_to, "LARTs " . $self->larter . " with a clue-by-four (" . $self->target . " not on this channel!)");
  $self->in_progress(0);
  return 1;
}

1;
