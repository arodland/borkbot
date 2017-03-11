package Borkbot::Module::shorten;
use Moo;
use Borkbot::Module;
use WWW::Shorten qw(TinyURL :short);

has 'min_len' => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    $self->bot->config->{shorten}{min_len} // 71
  }
);

sub do_shorten {
  my ($self, $ev) = @_;
  my $min_len = $self->min_len;

  my ($url, $addressed);

  if ($ev->msg =~ /^.shorten\s+(https?:\/\/.*)/i) {
    $url = $1;
    $addressed = 1;
  } elsif ($min_len &&  $ev->msg =~ m#(https?://\S{$min_len,})#) {
    $url = $1;
    $addressed = 0;
  } else {
    return 0;
  }

  Mojo::IOLoop->subprocess(
    sub {
      short_link($url);
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

  return 0;
}

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  unless ($ev->msg =~ /^\.remember/i) {
    $self->do_shorten($ev);
  }
}

sub on_ctcp_action {
  my ($self, $ev) = @_;
  $self->do_shorten($ev);
}

1;
