package Borkbot::Module::shorten;
use Moo;
use Borkbot::Module;

has 'shorten_provider' => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    $self->bot->config->{shorten}{provider} // 'TinyURL';
  }
);

has 'shorten_options' => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    $self->bot->{config}{shorten}{options};
  }
);

has 'min_len' => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    $self->bot->config->{shorten}{min_len} // 71
  }
);

sub BUILD {
  my ($self) = @_;
  my $module = "WWW::Shorten::" . $self->shorten_provider;
  (my $file = "$module.pm") =~ s[::][/]g;
  require $file;
  $module->import(':short');
  log_info { "Loaded $module" };
}

sub do_shorten {
  my ($self, $ev) = @_;
  my $min_len = $self->min_len;

  my ($url, $addressed);

  if ($ev->msg =~ /^.shorten\s+(https?:\/\/.*)/i) {
    $url = $1;
    $addressed = 1;
  } elsif ($ev->visibility eq 'public' && $min_len && $ev->msg =~ m#(https?://\S{$min_len,})#) {
    $url = $1;
    $addressed = 0;
  } else {
    return 0;
  }

  Mojo::IOLoop->subprocess(
    sub {
      short_link($url, %{ $self->shorten_options || {} });
    },
    sub {
      my ($subprocess, $err, $short_url) = @_;
      if ($err) {
        $err =~ s/\n\z//;
        log_warning { "short_link failed with $err" };
        if ($addressed) { # Fail silently if we weren't specifically asked to shorten
          $self->irc->privmsg($ev->reply_to, "[shorten] error.");
        }
      } else {
        $self->irc->privmsg($ev->reply_to, $ev->nick . "'s URL is at: $short_url");
      }
    }
  );

  return $addressed;
}

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  $self->do_shorten($ev);
}

sub on_ctcp_action {
  my ($self, $ev) = @_;
  $self->do_shorten($ev);
}

1;
