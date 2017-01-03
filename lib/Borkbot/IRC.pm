package Borkbot::IRC;
use strict;
use warnings;
use base 'Mojo::IRC::UA';
use Parse::IRC;

sub new {
  my $self = shift;
  return $self->SUPER::new(
    @_,
    parser => Parse::IRC->new(ctcp => 1),
  );
}

1;
