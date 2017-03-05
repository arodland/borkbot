package Borkbot::IRC;
use strict;
use warnings;
use Mojo::Base 'Mojo::IRC::UA';
use Parse::IRC;

has 'bot';

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    parser => Parse::IRC->new(ctcp => 1),
    track_any => 1,
    @_,
  );
  return $self;
}

1;
