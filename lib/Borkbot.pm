package Borkbot;
use Moo;
use MooX::Options;

use YAML::Tiny;
use Mojo::Pg;
use Mojo::IRC;

use Borkbot::Logger;

option 'config_file' => (
  is => 'ro',
  format => 's',
  short => 'C',
  default => "borkbot.yaml",
);

has 'config' => (
  is => 'lazy',
  default => sub {
    my $self = shift;
    YAML::Tiny->read($self->config_file)->[0];
  },
);

has 'pg' => (
  is => 'lazy',
  default => sub {
    my $self = shift;
    Mojo::Pg->new(%{ $self->config->{db} });
  },
);

has 'irc' => (
  is => 'lazy',
  default => sub {
    my $self = shift;
    my $config = $self->config->{irc};

    Mojo::IRC->new(
      server => $config->{server},
      nick => $config->{nick},
      name => $config->{ircname},
      user => $config->{username},
      tls => $config->{tls},
    );
  },
);

has 'modules' => (
  is => 'rw',
);

sub run {
  my ($self) = shift;
  Borkbot::Logger::set_logfile($self->config->{log}{file});
  Borkbot::Logger::set_stderr($self->config->{log}{stderr});
  log_info { "started up!" };
}

1;
