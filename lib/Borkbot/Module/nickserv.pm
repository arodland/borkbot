package Borkbot::Module::nickserv;
use Moo;
use Borkbot::Module;

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  my $password = $self->bot->config->{nickserv}{password};
  return 0 unless defined $password;

  if ($self->is_control_channel($ev->to)) {
    if ($ev->msg =~ /^\.register\s*$/i) {
      log_info { "registering." };
      $self->irc->privmsg("nickserv", "register $password");
      return 1;
    } elsif ($ev->msg =~ /^\.identify\s*$/i) {
      log_info { "identifying." };
      $self->irc->privmsg("nickserv", "identify $password");
      return 1;
    }
  } elsif (lc $ev->nick eq 'nickserv' && $ev->msg =~ /This nick belongs to another user/i) {
    log_info { "identifying." };
    $self->irc->privmsg("nickserv", "identify $password");
    return 1;
  }

  return 0;
}

sub on_irc_rpl_endofmotd {
  my ($self, $ev) = @_;


  my $password = $self->bot->config->{nickserv_password};
  return 0 unless defined $password;
  log_info { "identifying." };
  $self->irc->privmsg("nickserv", "identify $password");
  return 1;
}

1;
