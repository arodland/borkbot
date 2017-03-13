package Borkbot::Module::remember;
use Moo;
use Borkbot::Module;
use Borkbot::Future;

has 'queries' => (
  is => 'rw',
  default => sub { +{} },
);

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  my $kw = qr/[\w\d\|\-\#\.:]+/;
  my $msg = $ev->msg;

  if ($msg =~ /^\.remember\s+($kw)\s+(.+)/i) {
    $self->do_remember($ev, $1, $2);
    return 1;
  } elsif ($msg =~ /^\.recall\s+($kw)\s*/i) {
    $self->do_recall($ev, $1);
    return 1;
  } elsif ($msg =~ /^\.match\s+($kw)\s+(.+)/i) {
    $self->do_match($ev, $1, $2);
    return 1;
  } elsif ($msg =~ /^\.details\s*$/i) {
    $self->do_details($ev);
    return 1;
  } elsif ($msg =~ /^\.next\s*$/i) {
    $self->do_prevnext($ev, 1);
    return 1;
  } elsif ($msg =~ /^\.prev\s*$/i) {
    $self->do_prevnext($ev, -1);
    return 1;
  } elsif ($msg =~ /^\.forget\s+($kw)\s+(.+)/i) {
    $self->do_forget($ev, $1, $2);
    return 1;
  } elsif ($msg =~ /^\.try_recall\s+($kw)\s*$/i) {
    $self->do_try_recall($ev, $1, $2);
  } elsif ($msg =~ /^\.(read_only|ro)\s+($kw)\s*$/i && $self->is_control_channel($ev->to)) {
    $self->do_readonly($ev, $2, 1);
    return 1;
  } elsif ($msg =~ /^\.(read_write|rw)\s+($kw)\s*$/i && $self->is_control_channel($ev->to)) {
    $self->do_readonly($ev, $2, 0);
    return 1;
  } elsif ($msg =~ /^\.(ordered|or)\s+($kw)\s*$/i) {
    $self->do_ordered($ev, $2, 1);
    return 1;
  } elsif ($msg =~ /^\.(uordered|uo)\s+($kw)\s*$/i) {
    $self->do_ordered($ev, $2, 0);
    return 1;
  } elsif ($msg =~ /^\.count\s+($kw)\s*$/i) {
    $self->do_count($ev, $1);
  # These (lyrics and urls) have to come after forget, so that lyrics and urls can be forgotten.
  } elsif ($msg =~ m[^(o/~|o/`) .+]) {
    $self->do_autoremember($ev, "lyrics", $msg);
    return 0;
  } elsif ($msg =~ m[((http|ftp)://\S+)]) {
    $self->do_autoremember($ev, "urls", $1);
    return 0;
  }
  return 0;
}

sub do_remember {
  my ($self, $ev, $keyword, $definition) = @_;

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

sub do_autoremember {
  my ($self, $ev, $keyword, $definition) = @_;

  $definition =~ s/\s+$//;

  if (length($definition) + length($keyword) > 220) {
    return;
    return;
  }

  $self->test_ro($keyword)
  ->then(sub {
    my ($test_ro) = @_;
    if ($test_ro) {
      return failure(qq{Warning: "$keyword" is read-only.});
    } else {
      $self->test_item($keyword, $definition)
    }
  })->then(sub {
    my ($test_item) = @_;
    if (!$test_item->rows) {
      $self->remember_item($keyword, $definition, $ev->nick)
    }
  })->else($self->curry::error_handler($ev))
  ->wait_ignore;
}

sub do_recall {
  my ($self, $ev, $keyword) = @_;

  my $items;

  $self->recall_item($keyword)
  ->then(sub {
    my ($db, $recall_item) = @_;

    if (!$recall_item->rows) {
      return failure("I don't know anything about $keyword.");
    } else {
      $items = $recall_item->hashes;
      $self->test_unordered($keyword);
    }
  })
  ->then(sub {
    my ($unordered) = @_;
    if ($unordered) {
      $items = $items->shuffle;
    }

    my $row = $items->[0];
    $self->irc->privmsg($ev->reply_to, "[$keyword] (1/" . $items->size . ($unordered ? "" : " ordered") . ") $row->{definition}");

    $self->queries->{$ev->reply_to} = {
      keyword => $keyword,
      items => $items,
      position => 0,
    };
    Borkbot::Future->done;
  })->else($self->curry::error_handler($ev))
  ->wait_ignore;
}

sub do_details {
  my ($self, $ev) = @_;
  if (my $q = $self->queries->{$ev->reply_to}) {
    my $item = $q->{items}->[ $q->{position} ];

    $self->irc->privmsg($ev->reply_to, "[$item->{keyword}] (" . ($q->{position} + 1) . "/" . $q->{items}->size . ") submitted by $item->{submitter} at " . $self->format_time($item->{time}) . ".");
  }
}

sub do_prevnext {
  my ($self, $ev, $offset) = @_;
  if (my $q = $self->queries->{$ev->reply_to}) {
    $q->{position} = ($q->{position} + $offset) % $q->{items}->size;
    my $item = $q->{items}->[ $q->{position} ];
    $self->irc->privmsg($ev->reply_to, "[$item->{keyword}] (" . ($q->{position} + 1) . "/" . $q->{items}->size . ") $item->{definition}");
  }
}

sub do_forget {
  my ($self, $ev, $keyword, $definition) = @_;

  $self->test_ro($keyword)
  ->then(sub {
    my ($ro) = @_;

    if ($ro) {
      return failure(qq{Sorry, "$keyword" is read-only.});
    } else {
      $self->forget_item($keyword, $definition)
    }
  })
  ->then(sub {
    my ($db, $result) = @_;
    if (!$result->rows) {
      return failure("No matching entry to forget for $keyword.");
    } else {
      $self->count($keyword);
    }
  })
  ->then(sub {
    my ($count) = @_;

    my $response = "Forgot an entry for $keyword.";

    if ($count == 0) {
      $response .= "  I now know nothing about $keyword.";
    } elsif ($count == 1) {
      $response .= "  There is now 1 entry.";
    } else {
      $response .= "  There are now $count entries.";
    }
    $self->irc->privmsg($ev->reply_to, $response);
    Borkbot::Future->done;
  })
  ->else($self->curry::error_handler($ev))
  ->wait_ignore;
}

sub do_try_recall {
  my ($self, $ev, $pattern) = @_;

  if (length($pattern) < 3) {
    $self->irc->privmsg($ev->reply_to, "Need at least 3 characters for try_recall.");
    return;
  }

  $pattern =~ s/_/\\_/g;
  $self->try_recall($pattern)
  ->then(sub {
    my ($db, $result) = @_;
    if ($result->rows) {
      $self->irc->privmsg($ev->reply_to, "[Possible matches for $pattern] " . $result->arrays->flatten->join(" "));
    } else {
      $self->irc->privmsg($ev->reply_to, "[No match for $pattern]");
    }
    Borkbot::Future->done;
  })
  ->else($self->curry::error_handler($ev))
  ->wait_ignore;
}

sub do_readonly {
  my ($self, $ev, $keyword, $readonly) = @_;
  my $desc = $readonly ? "read only" : "read write";

  $self->set_ro($keyword, $readonly)
  ->then(sub {
    my ($db, $result) = @_;
    if ($result->rows) {
      $self->irc->privmsg($ev->reply_to, "$keyword set $desc.");
    } else {
      $self->irc->privmsg($ev->reply_to, "$keyword not set $desc (not found?)");
    }
    Borkbot::Future->done;
  })
  ->else($self->curry::error_handler($ev))
  ->wait_ignore;
}

sub do_ordered {
  my ($self, $ev, $keyword, $ordered) = @_;
  my $desc = $ordered ? "ordered" : "unordered";

  $self->test_ro($keyword)
  ->then(sub {
    my ($ro) = @_;
    if ($ro) {
      return failure(qq{Sorry, "$keyword" is read-only."});
    } else {
      $self->set_ordered($keyword, $ordered);
    }
  })
  ->then(sub {
    my ($db, $result) = @_;
    if ($result->rows) {
      $self->irc->privmsg($ev->reply_to, "$keyword set $desc.");
    } else {
      $self->irc->privmsg($ev->reply_to, "$keyword not set $desc (not found?)");
    }
    Borkbot::Future->done;
  })
  ->else($self->curry::error_handler($ev))
  ->wait_ignore;
}

sub do_count {
  my ($self, $ev, $keyword) = @_;

  if ($keyword eq '*') {
    $self->count_all()
    ->then(sub {
      my ($count) = @_;
      $self->irc->privmsg($ev->reply_to, "There are $count total entries.");
      Borkbot::Future->done;
    })
    ->else($self->curry::error_handler($ev))
    ->wait_ignore;
  } else {
    $self->count($keyword)
    ->then(sub {
      my ($count) = @_;
      if ($count == 1) {
        $self->irc->privmsg($ev->reply_to, "There is $count entry for $keyword.");
      } else {
        $self->irc->privmsg($ev->reply_to, "There are $count entries for $keyword.");
      }
      Borkbot::Future->done;
    })
    ->else($self->curry::error_handler($ev))
    ->wait_ignore;
  }
}

sub test_ro {
  my ($self, $keyword) = @_;

  future($self->pg->db->curry::select('memory', 'count(*)', { keyword => lc($keyword), ro => 't' }))
  ->then(sub {
    my ($db, $result) = @_;
    return Borkbot::Future->done($result->array->[0]);
  });
}

sub test_unordered {
  my ($self, $keyword) = @_;
  
  future($self->pg->db->curry::select('memory', 'count(*)', { keyword => lc($keyword), ordered => 'f' }))
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

  future($self->pg->db->curry::select('memory', 'count(*) as count', { keyword => lc($keyword) }))
  ->then(sub {
    my ($db, $result) = @_;
    return Borkbot::Future->done($result->array->[0]);
  });
}

sub count_all {
  my ($self) = @_;
  future($self->pg->db->select('memory', 'count(*)'))
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

sub recall_item {
  my ($self, $keyword) = @_;

  future($self->pg->db->curry::select('memory', undef, { keyword => lc $keyword }, { -asc => 'time' }));
}

sub forget_item {
  my ($self, $keyword, $definition) = @_;
  future($self->pg->db->curry::delete('memory', { keyword => lc $keyword, definition => $definition }));
}

sub try_recall {
  my ($self, $pattern) = @_;
  future($self->pg->db->curry::select('memory', ['keyword'], { keyword => { -ilike => "%${pattern}%" } }));
}

sub set_readonly {
  my ($self, $keyword, $readonly) = @_;
  future($self->pg->db->curry::update('memory', { ro => $readonly ? 't' : 'f' }, { keyword => lc $keyword }));
}

sub set_ordered {
  my ($self, $keyword, $ordered) = @_;
  future($self->pg->db->curry::update('memory', { ordered => $ordered ? 't' : 'f' }, { keyword => lc $keyword }));
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

1;
