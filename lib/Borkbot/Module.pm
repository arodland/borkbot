package Borkbot::Module;
use Moo;

has 'bot' => (
  is => 'ro',
  weak_ref => 1,
  handles => [qw(
    irc
    ua
    pg
    is_control_channel
  )],
);

sub import {
  my $class = shift;
  my $target = caller(0);

  unless ($target->isa("Moo::Object")) {
    eval "package $target; use Moo;";
  }

  eval "package $target; use Borkbot::Logger;";

  unless ($target->isa("Borkbot::Module")) {
    eval "package $target; extends 'Borkbot::Module';";
  }
}

1;
