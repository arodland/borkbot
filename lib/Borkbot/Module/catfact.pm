package Borkbot::Module::catfact;
use Moo;
use Borkbot::Module;
use Borkbot::Future;

sub do_api {
  my ($self, $ev) = @_;

  $self->ua->get('https://catfacts-api.appspot.com/api/facts' => sub {
      my ($ua, $tx) = @_;
      my $res = $tx->result;
      if ($res->is_error) {
        $self->irc->privmsg($ev->reply_to, "Catfact can has error: " . $res->message);
        return;
      }
      my $fact = $res->json('/facts/0');
      $self->irc->privmsg($ev->reply_to, $fact);
  });
}

sub do_factoid {
  my ($self, $ev) = @_;

  future($self->pg->db->curry::query(
    "select definition from memory"
    ." where keyword='catfacts'"
    ." order by random() limit 1"
  ))->then(sub {
    my ($db, $result) = @_;
    if ($result->rows == 0) {
      $self->irc->privmsg($ev->reply_to, "Some say he only knows two facts about kittens, and both of them are wrong. All we know is, he's called the " . $self->irc->nick . ".");
    } else {
      $self->irc->privmsg($ev->reply_to, $result->array->[0]);
    }
    return Borkbot::Future->done;
  })->else(sub {
    my ($err) = @_;
    log_warning { $err };
  })->wait_ignore;
}

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  return 0 unless $ev->{msg} =~ /^\.catfact\s*$/i;
  if (rand() < 0.5) {
    $self->do_api($ev); # Get it from the catfacts API
  } else {
    $self->do_factoid($ev); # Get it from the DB
  }
  return 1;
}

1;
