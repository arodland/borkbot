package Borkbot;
use Moo;
use MooX::Options;

use Try::Tiny;
use YAML::Tiny;
use Mojo::Pg;
use Mojo::IRC;
use again;
use experimental 'postderef';

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
    Mojo::Pg->new($self->config->{db}->%*);
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
  default => sub { +{} },
);

has 'module_order' => (
  is => 'rw',
  default => sub { +[] },
);

sub load_module {
  my ($self, $name) = @_;
  my $module = "Borkbot::Module::$name";

  log_info { "Loading $name" };
  try {
    delete $Moo::MAKERS{$module};
    require_again $module;
    $self->modules->{$name} = $module->new(
      bot => $self,
    );
    1;
  } catch {
    log_warning { "Loading $module failed: $_" }
    0;
  };
}

sub run {
  my ($self) = shift;
  Borkbot::Logger::set_logfile($self->config->{log}{file});
  Borkbot::Logger::set_stderr($self->config->{log}{stderr});
  log_info { "started up!" };

  for my $module ($self->config->{modules}->@*) {
    if ($self->load_module($module)) {
      push $self->module_order->@*, $module;
    }
  }
}

1;
