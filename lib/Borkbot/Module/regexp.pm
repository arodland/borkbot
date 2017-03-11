package Borkbot::Module::regexp;
use Moo;
use Borkbot::Module;
use experimental 'postderef';

has 'history' => (
  is => 'rw',
  default => sub { +{} },
);

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  return 0 unless $ev->visibility eq 'public';
  my $channel = $ev->to;

  my $history_len = $self->bot->config->{regexp}{history_len} // 30;

  if (my $history = $self->history->{$channel}) {
    if (my ($match, $replace, $opts) = $ev->msg =~ m|^\.s/([^/]+)/([^/]*)/(g?)\s*$|) {
      for my $line (@$history) {
        if (lc $line->{nick} eq lc $ev->nick) {
          my $matched;
          if ($opts =~ /g/) {
            $matched = $line->{msg} =~ s/$match/$replace/g;
          } else {
            $matched = $line->{msg} =~ s/$match/$replace/;
          }
          next unless $matched;

          my $msg = $line->{type} eq 'ctcp_action' ? "* $line->{nick} " : "<$line->{nick}> ";
          $msg .= $line->{msg};
          $self->irc->privmsg($ev->reply_to, $msg);
          return 1;
        }
      }
      return 0; # Recognized .s/// without matching anything
    }
  }

  unshift $self->history->{$channel}->@*, {
    nick => $ev->nick,
    msg => $ev->msg,
    type => $ev->type,
  };

  splice $self->history->{$channel}->@*, $history_len;

  return 0;
}

sub on_ctcp_action {
  my ($self, $ev) = @_;

  return 0 unless $ev->visibility eq 'public';
  my $channel = $ev->to;

  my $history_len = $self->bot->config->{regexp}{history_len} // 30;

  unshift $self->history->{$channel}->@*, {
    nick => $ev->nick,
    msg => $ev->msg,
    type => $ev->type,
  };

  splice $self->history->{$channel}->@*, $history_len;

  return 0;
}

1;
