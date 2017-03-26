package Borkbot::Module::catfact;
use Moo;
use Borkbot::Module;
use Mojo::UserAgent;

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  return 0 unless $ev->{msg} =~ /^\.catfact\s*$/i;

  $self->ua->get('https://catfacts-api.appspot.com/api/facts' => sub {
      my ($ua, $tx) = @_;
      my $res = $tx->result;
      if ($res->is_error) {
        $self->irc->privmsg($ev->{reply_to}, "Catfact can has error: " . $res->message);
        return;
      }
      my $fact = $res->headers->json('/facts/0');
      $self->irc->privmsg($ev->{reply_to}, "Thank you for subscribing to CatFacts(tm)!");
      $self->irc->privmsg($ev->{reply_to}, $fact);
  });

  return 1;
}

1;
