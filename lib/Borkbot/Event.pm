package Borkbot::Event;
use Moo;
use experimental 'postderef';

has [qw(type raw from to nick user host visibility msg reply_to channel raw_args)] => (
  is => 'rw',
);

my %event_args = (
  err_nicknameinuse => [ 'cmd', 'nick', 'msg' ],
  irc_join => ['channel'],
  irc_nick => ['newnick'],
  irc_mode => ['target', 'modes'],
  irc_notice => ['target', 'msg'],
  irc_part => ['channel'],
  irc_ping => ['ts'],
  irc_privmsg => ['target', 'msg'],
);

sub from_mojo_event {
  my ($class, $ev) = @_;

  $ev->{event} = "irc_" . $ev->{event} unless $ev->{event} =~ /^(ctcp|err)_/;

  my %args = (
    type => $ev->{event},
    raw_args => $ev->{params},
  );

  if (defined $ev->{raw_line}) {
    $args{raw_line} = $ev->{raw_line};
  }
  if (defined $ev->{prefix}) {
    $args{from} = $ev->{prefix};
    if ($ev->{prefix} =~ /([^!]+)!([^@]+)\@(.*)/) {
      $args{nick} = $1;
      $args{user} = $2;
      $args{host} = $3;
    }
  }

  if ($args{type} eq 'irc_join' || $args{type} eq 'irc_part') {
    $args{channel} = $ev->{params}[0];
  } elsif ($args{type} eq 'irc_notice' || $args{type} eq 'irc_privmsg' || $args{type} =~ /^ctcp_/) {
    ($args{to}, $args{msg}) = $ev->{params}->@*;
    if ($args{to} =~ /^#/) {
      $args{visibility} = 'public';
      $args{reply_to} = $args{to};
    } else {
      $args{visibility} = 'private';
      $args{reply_to} = $args{nick};
    }
  } elsif ($args{type} eq 'irc_nick') {
    $args{newnick} = $ev->{params}[0];
  } elsif ($args{type} eq 'irc_mode') {
    ($args{to}, $args{modes}) = $ev->{params}->@*;
    if ($args{to} =~ /^#/) {
      $args{type} = 'chanmode';
    } else {
      $args{type} = 'usermode';
    }
  }
  return $class->new(%args);
}

sub userhost {
  my ($self) = @_;
  return $self->user . '@' . $self->host;
}

1;
