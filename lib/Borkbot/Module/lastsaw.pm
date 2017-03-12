package Borkbot::Module::lastsaw;
use Moo;
use Borkbot::Module;

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

  # This isn't pretty, but it is async.
  # Could be better if adapted to use promises?
  my $txn = $db->begin;
  $db->update('lastsaw', { lastsaid => $last_msg, time => \'CURRENT_TIMESTAMP' }, { person => $nick }, sub {
      my ($db, $err, $results) = @_;
      if ($err) {
        log_warning { "DB error: $err" };
        return;
      }
      if ($results->rows == 0) {
        $db->insert('lastsaw', { lastsaid => $last_msg, time => \'CURRENT_TIMESTAMP', person => $nick }, sub {
            my ($db, $err, $results) = @_;
            if ($err) {
              log_warning { "DB error: $err" };
              return;
            }
            $txn->commit;
          }
        );
      } else {
        $txn->commit;
      }
    }
  );

  return 0;
}

sub get_lastsaw {
  my ($self, $nick, $cb) = @_;
  $self->pg->db->select('lastsaw', ['time','lastsaid'], { person => $nick }, sub {
      my ($db, $err, $results) = @_;
      if ($err) {
        log_warning { "DB error: $err" };
        $cb->(undef);
        return;
      }
      $cb->($results->hash);
    }
  );
}

sub do_lastsaw {
  my ($self, $ev, $nick) = @_;
  $self->get_lastsaw(lc $nick, sub {
      my ($row) = @_;
      if ($row) {
        $self->irc->privmsg($ev->reply_to, "Last saw $nick at $row->{time}");
      } else {
        $self->irc->privmsg($ev->reply_to, "I've never seen $nick");
      }
    }
  );
}

sub do_lastsaid {
  my ($self, $ev, $nick) = @_;
  $self->get_lastsaw(lc $nick, sub {
      my ($row) = @_;
      if ($row) {
        $self->irc->privmsg($ev->reply_to, "$nick last said: $row->{lastsaid}");
      } else {
        $self->irc->privmsg($ev->reply_to, "I've never seen $nick");
      }
    }
  );
}

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  if ($ev->msg =~ /^\.lastsaw\s+([\w\-_\|\^\`]+)/i) {
    $self->do_lastsaw($ev, $1);
  } elsif ($ev->msg =~ /^\.lastsaid\s+([\w\-_\|\^\`]+)/i) {
    $self->do_lastsaid($ev, $1);
  }
  $self->update_saw($ev) if $ev->visibility eq 'public';
}

sub on_ctcp_action {
  my ($self, $ev) = @_;
  $self->update_saw($ev) if $ev->visibility eq 'public';
}


1;
