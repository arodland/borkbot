package Borkbot::Module::catfact_db;
use Moo;
use Borkbot::Module;
use Borkbot::Future;

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  return 0 unless $ev->{msg} =~ /^\.catfact\s*$/i;

  future($self->pg->db->curry::query(
    "select definition from memory"
    ." where keyword='catfact'"
    ." order by random() limit 1"
  ))->then(sub {
    my ($db, $result) = @_;
    if ($result->rows == 0) {
      $self->irc->privmsg($ev->reply_to, "Some say he only knows two facts about kittens, and they're both wrong.");
    } else {
      $self->irc->privmsg($result->array->[0]);
    }
    return Borkbot::Future->done;
  })->else(sub {
    my ($err) = @_;
    log_warning { $err };
  })->wait_ignore;
  return 1;
}

1;
