package Borkbot::Module::remember;
use Moo;
use Borkbot::Module;
use Borkbot::Future;
use List::Util qw(shuffle);

sub test_ro {
  my ($self, $keyword) = @_;

  future($self->pg->db->curry::select('memory', 'count(*)', { keyword => lc($keyword), ro => 't' }))
  ->then(sub {
    my ($db, $result) = @_;
    return Borkbot::Future->done($result->array->[0]);
  });
}

sub test_item {
  my ($self, $keyword, $definition) = @_;

  future($self->pg->db->curry::select('memory', ['keyword', 'submitter', 'time'], { keyword => lc($keyword), definition => $definition }))
  ->then(sub {
    my ($db, $result) = @_;
    return Borkbot::Future->done($result);
  });
}

sub count {
  my ($self, $keyword) = @_;

  future($self->pg->db->curry::select('memory', 'count(*)', { keyword => lc($keyword) }))
  ->then(sub {
    my ($db, $result) = @_;
    return Borkbot::Future->done($result->array->[0]);
  });
}

sub remember_item {
  my ($self, $keyword, $definition, $nick) = @_;

  future($self->pg->db->curry::insert('memory', {
      keyword => lc $keyword,
      definition => $definition,
      submitter => $nick,
      time => \'CURRENT_TIMESTAMP',
      ordered => 'f'
  }));
}

sub failure {
  my ($msg) = @_;
  my $failure = bless \$msg, 'Borkbot::Failure';
  return Borkbot::Future->fail($failure);
}

sub error_handler {
  my ($self, $ev, $err) = @_;
  if ($err && $err->isa('Borkbot::Failure')) {
    $self->irc->privmsg($ev->reply_to, $$err);
  } else {
    log_warning { $err };
  }
  return Borkbot::Future->done;
}

sub format_time {
  my ($self, $timestamp) = @_;
  if (my ($date, $time, $timezone) = $timestamp =~ /([\d\-]+) ([\d:]+)\.[0-9]+([+\-][0-9]{2})/) {
    return "$date $time [GMT $timezone]";
  } else {
    return "an unknown time";
  }
}

sub do_remember {
  my ($self, $ev, $keyword, $definition) = @_;

  log_info { "entered do_remember" };

  $definition =~ s/\s+$//;

  if (length($keyword) > 50) {
    $self->irc->privmsg($ev->reply_to, "Sorry, your keyword is too long.");
    return;
  }

  if (length($definition) + length($keyword) > 220) {
    $self->irc->privmsg($ev->reply_to, "Sorry, your keyword/definition combination are too long.");
    return;
  }

  $self->test_ro($keyword)
  ->then(sub {
    my ($test_ro) = @_;
    if ($test_ro) {
      return failure(qq{Sorry, "$keyword" is read-only.});
    } else {
      $self->test_item($keyword, $definition)
    }
  })->then(sub {
    my ($test_item) = @_;
    if (!$test_item->rows) {
      $self->remember_item($keyword, $definition, $ev->nick)
      ->then(sub {
        $self->count($keyword);
      })->then(sub {
        my ($count) = @_;
        my $response = "Entry added for $keyword.";
        if ($count == 1) {
          $response .= "  This is the first entry.";
        } else {
          $response .= "  There are now $count entries.";
        }
        $self->irc->privmsg($ev->reply_to, $response);
        Borkbot::Future->done;
      });
    } else {
      my $item = $test_item->hash;
      my $response = "I already know that about $keyword.  It was added by $item->{submitter} at " . $self->format_time($item->{time}) . ".";
      $self->count($keyword)->then(sub {
        my ($count) = @_;
        if ($count == 1) {
          $response .= "  I know 1 thing about $keyword.";
        }  else {
          $response .= "  I know $count things about $keyword.";
        }
        $self->irc->privmsg($ev->reply_to, $response);
        Borkbot::Future->done;
      });
    }
  })->else($self->curry::error_handler($ev))
  ->wait_ignore;
}

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  if ($ev->msg =~ /^\.remember\s+([\w\d\|\-\#\.:]+)\s+(.+)/i) {
    $self->do_remember($ev, $1, $2);
    return 1;
  }

  return 0;
}

1;
