package Borkbot::Module::control;
use Moo;
use Borkbot::Module;

has 'control_channel_raw' => (
  is => 'ro',
  lazy => 1,
  default => sub {
    shift->bot->config->{irc}{control_channel},
  },
);

has 'control_channel' => (
  is => 'rw',
  lazy => 1,
  default => sub {
    (split " ", shift->control_channel_raw)[0];
  },
);

sub on_irc_rpl_endofmotd {
  my ($self, $ev) = @_;

  my $control_channel = $self->control_channel_raw;

  return unless $control_channel;

  log_info { "Joining control channel." };

  $self->irc->join($control_channel);
}

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  return 0 unless $ev->to eq $self->control_channel;

  log_info { "<" . $ev->from . "> " . $ev->msg };

  if ($ev->msg =~ /^\.(?:re)?load\s+(\S+)$/i) {
    $self->bot->load_and_append_module($1);
    return 1;
  } elsif ($ev->msg =~ /^\.unload\s+(\S+)$/i) {
    $self->bot->unload_module($1);
    return 1;
  } elsif ($ev->msg =~ /^\.join\s+(\S+)$/i) {
    $self->irc->join($1);
    return 1;
  } elsif ($ev->msg =~ /^\.leave\s(\S+)$/i) {
    $self->irc->part($1);
    return 1;
  } elsif ($ev->msg =~ /^\.reload_config\s*$/i) {
    $self->bot->clear_config;
    $self->bot->config;
    return 1;
  }

  return 0;
}

1;
