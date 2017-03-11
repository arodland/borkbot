package Borkbot::Module::calc;
use Moo;
use Borkbot::Module;

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  return 0 unless $ev->msg =~ /^\.calc\s+(.*)/i;
  my $expr = $1;

  $self->ua->get('http://www.google.com/search', form => {q => $expr} => sub {
      my ($ua, $tx) = @_;
      my $res = $tx->result;
      my $response;

      if (!$res->is_error && $res->dom && (my $elem = $res->dom->at('#res h2'))) {
        $response = $elem->all_text;
      } else {
        $response = "A suffusion of yellow.";
      }

      $self->irc->privmsg($ev->reply_to, $response);
  });
  return 1;
}

1;
