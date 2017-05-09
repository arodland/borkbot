package Borkbot;
use Moo;
use MooX::Options;

use Try::Tiny;
use YAML::Tiny;
use Mojo::Pg;
use Mojo::UserAgent;
use App::Nopaste ();

use again;
use experimental 'postderef';

use Borkbot::Logger;
use Borkbot::IRC;
use Borkbot::Event;

our $VERSION = '0.10';

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
  clearer => 'clear_config',
);

has 'pg' => (
  is => 'lazy',
  default => sub {
    my $self = shift;
    my $config = $self->config->{db};
    my $pg = Mojo::Pg->new;
    $pg->dsn($config->{dsn});
    $pg->username($config->{username}) if defined $config->{username};
    $pg->password($config->{password}) if defined $config->{password};
    if ($config->{debug}) {
      $pg->options(
        { 
          AutoCommit => 1,
          RaiseError => 1,
          pg_server_prepare => 0,
          TraceLevel => DBD::Pg->parse_trace_flag('SQL') 
        }
      );
    }
    $pg;
  },
);

has 'ua' => (
  is => 'lazy',
  default => sub {
    Mojo::UserAgent->new;
  },
);

has 'irc' => (
  is => 'lazy',
  default => sub {
    my $self = shift;
    my $config = $self->config->{irc};

    Borkbot::IRC->new(
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

has 'debug_events' => (
  is => 'rw',
  default => 0,
);

has 'in_channels' => (
  is => 'rw',
  default => sub { +{} },
);

sub in_channel {
  my ($self, $channel) = @_;
  return exists($self->in_channels->{$channel}) ? 1 : 0;
}

sub is_control_channel {
  my ($self, $channel) = @_;
  return 0 unless exists $self->modules->{control};
  return lc($channel) eq lc($self->modules->{control}->control_channel);
}

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
    log_warning { "Loading $module failed: $_" };
    0;
  };
}

sub nopaste {
  my ($self, @args) = @_;
  local $ENV{NOPASTE_MOJOPASTE_WEBPATH};
  if (my $url = $self->config->{nopaste}{url}) {
    $ENV{NOPASTE_MOJOPASTE_WEBPATH} = $url;
  }
  return App::Nopaste::nopaste(
    services => ['Mojopaste'],
    nick => $self->irc->nick,
    @args,
  );
}


sub load_and_append_module {
  my ($self, $name) = @_;
  unless ($self->load_module($name)) {
    return 0;
  }
  unless (grep { $_ eq $name } $self->module_order->@*) {
    push $self->module_order->@*, $name;
  }
  return 1;
}

sub unload_module {
  my ($self, $name) = @_;

  log_info { "Unloading $name" };

  delete $self->modules->{$name};
  $self->module_order([
    grep { $_ ne $name } $self->module_order->@*
  ]);
}

sub get_handlers {
  my ($self, $method) = @_;
  return grep { $_->can($method) } $self, map { $self->modules->{$_} } $self->module_order->@*;
}

sub dispatch_event {
  my ($self, $event) = @_;

  my $type = $event->type;
  my $method = "on_$type";
  my @handlers = $self->get_handlers($method);

  for my $handler (@handlers) {
    my $stop = $handler->$method($event);
    last if $stop;
  }
}

sub on_irc_join {
  my ($self, $ev) = @_;

  return 0 unless $ev->nick eq $self->irc->nick;

  log_info { "Joined " . $ev->channel };
  $self->in_channels->{$ev->channel} = 1;
  return 0;
}

sub on_irc_part {
  my ($self, $ev) = @_;

  return 0 unless $ev->nick eq $self->irc->nick;

  log_info { "Left " . $ev->channel };
  delete $self->in_channels->{$ev->channel};
  return 0;
}

sub connect {
  my ($self) = shift;

  log_info { "connecting to IRC." };
  $self->irc->connect(sub {
      my ($irc, $err) = @_;
      if ($err) {
        $self->dispatch_event(Borkbot::Event->new(type => 'irc_connect_error', error => $err));
      } else {
        $self->dispatch_event(Borkbot::Event->new(type => 'irc_connected'));
      }
  });
}

sub run {
  my ($self) = shift;
  Borkbot::Logger::set_logfile($self->config->{log}{file});
  Borkbot::Logger::set_stderr($self->config->{log}{stderr});
  log_info { "started up!" };

  for my $module ($self->config->{modules}->@*) {
    $self->load_and_append_module($module);
  }
  
  $self->irc->on(message => sub {
    my ($irc, $ev) = @_;
    my $event = Borkbot::Event->from_mojo_event($ev);
    log_debug { use Data::Dumper::Concise; Dumper($event) };
    $self->dispatch_event($event);
  });

  $self->connect;

  Mojo::IOLoop->start;
}

1;
