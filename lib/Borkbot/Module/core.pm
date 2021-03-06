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

sub on_ctcp_time {
  my ($self, $ev) = @_;
  $self->irc->nctcp($ev->{reply_to}, TIME => scalar localtime);
  return 1;
}

sub on_irc_connect_error {
  my ($self, $ev) = @_;
  my $wait = $self->bot->config->{irc}{reconnect_wait} || 120;
  log_warning { "IRC connection error: " . $ev->{error} . ", reconnecting in $wait seconds." };
  Mojo::IOLoop->timer($wait => $self->bot->curry::connect);
}

sub on_irc_close {
  my ($self, $ev) = @_;
  log_warning { "IRC disconnected, reconnecting..." };
  $self->bot->connect;
}

sub on_irc_error {
  my ($self, $ev) = @_;
  log_warning { "IRC stream error: " . $ev->{error} . ", reconnecting..." };
  $self->bot->connect;
}

1;
