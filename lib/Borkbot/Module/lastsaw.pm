package Borkbot::Module::lastsaw;
use Moo;
use Borkbot::Module;
use Borkbot::Future;
use curry;

sub update_saw {
  my ($self, $ev) = @_;

  my $last_msg;

  if ($ev->type eq 'irc_privmsg') {
    $last_msg = "<" . $ev->nick . "> " . $ev->msg;
  } elsif ($ev->type eq 'ctcp_action') {
    $last_msg = "* " . $ev->nick . " " . $ev->msg;
  } else {
    log_warning { "called with unknown event type" };
    return;
  }

  my $nick = lc $ev->nick;
  my $db = $self->pg->db;

  my $txn = $db->begin;
  future($db->curry::update('lastsaw', { lastsaid => $last_msg, time => \'CURRENT_TIMESTAMP' }, { person => $nick }))
  ->then(sub {
    my ($db, $results) = @_;
    if ($results->rows == 0) {
      return future $db->curry::insert('lastsaw', { lastsaid => $last_msg, time => \'CURRENT_TIMESTAMP', person => $nick });
    } else {
      return Borkbot::Future->done;
    }
  })->then(sub {
    $txn->commit;
    return Borkbot::Future->done;
  })->else(sub {
    my ($err) = @_;
    log_warning { "DB error: $err" };
  })->wait_ignore;

  return 0;
}

sub get_lastsaw {
  my ($self, $nick) = @_;
  future($self->pg->db->curry::select('lastsaw', ['time','lastsaid'], { person => $nick }))
  ->then(sub {
    my ($db, $results) = @_;
    return Borkbot::Future->done($results->hash);
  })->else(sub {
    my ($err) = @_;
    log_warning { "DB error: $err" };
    return Borkbot::Future->done(undef);
  });
}

sub do_lastsaw {
  my ($self, $ev, $nick) = @_;
  $self->get_lastsaw(lc $nick)
  ->then(sub {
      my ($row) = @_;
      if ($row) {
        $self->irc->privmsg($ev->reply_to, "Last saw $nick at $row->{time}");
      } else {
        $self->irc->privmsg($ev->reply_to, "I've never seen $nick");
      }
  })->wait_ignore;
}

sub do_lastsaid {
  my ($self, $ev, $nick) = @_;
  $self->get_lastsaw(lc $nick)
  ->then(sub {
      my ($row) = @_;
      if ($row) {
        $self->irc->privmsg($ev->reply_to, "$nick last said: $row->{lastsaid}");
      } else {
        $self->irc->privmsg($ev->reply_to, "I've never seen $nick");
      }
  })->wait_ignore;
}

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  if ($ev->msg =~ /^\.lastsaw\s+([\w\-_\|\^\`]+)/i) {
    $self->do_lastsaw($ev, $1);
  } elsif ($ev->msg =~ /^\.lastsaid\s+([\w\-_\|\^\`]+)/i) {
    $self->do_lastsaid($ev, $1);
  }
  $self->update_saw($ev) if $ev->visibility eq 'public' && !$self->is_control_channel($ev->to);
  return 0;
}

sub on_ctcp_action {
  my ($self, $ev) = @_;
  $self->update_saw($ev) if $ev->visibility eq 'public' && !$self->is_control_channel($ev->to);
  return 0;
}


1;
