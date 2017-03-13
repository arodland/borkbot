package Borkbot::Module::core;
use Moo;
use Borkbot::Module;
use experimental 'postderef';

sub BUILD {
  log_info { "Borkbot core online" }
}

sub on_irc_rpl_endofmotd {
  my ($self, $ev) = @_;

  log_info { "Connected, joining channels." };

  for my $channel ($self->bot->config->{irc}{channels}->@*) {
    $self->irc->join($channel);
  }
  return 0;
}

sub on_ctcp_ping {
  my ($self, $ev) = @_;
  $self->irc->nctcp($ev->{reply_to}, PING => $ev->{msg});
  return 1;
}

sub on_ctcp_version {
  my ($self, $ev) = @_;
  $self->irc->nctcp($ev->{reply_to}, VERSION => "Borkbot $Borkbot::VERSION (core by hobbs, sporksbot by beez, contributions from various sporkers)");
  $self->irc->nctcp($ev->{reply_to}, VERSION => "Modules loaded: " . join(", ", sort keys $self->bot->modules->%*));
  return 1;
}

sub on_ctcp_time {
  my ($self, $ev) = @_;
  $self->irc->nctcp($ev->{reply_to}, TIME => scalar localtime);
  return 1;
}

1;
