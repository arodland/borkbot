package Borkbot::Module::kitty;
use Moo;
use Borkbot::Module;
use Mojo::UserAgent;

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  return 0 unless $ev->{msg} =~ /^\.kitty\s*$/i;

  $self->ua->get('http://thecatapi.com/api/images/get?format=src' => sub {
      my ($ua, $tx) = @_;
      my $res = $tx->result;
      if ($res->is_error) {
        $self->irc->privmsg($ev->{reply_to}, "Kitty can has error: " . $res->message);
        return;
      }
      $self->irc->privmsg($ev->{reply_to}, $res->headers->location);
  });

  return 1;
}

1;
