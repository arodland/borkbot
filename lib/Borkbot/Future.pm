package Borkbot::Future;
use strict;
use warnings;
use base 'Future::Mojo';

use feature 'state';
use Scalar::Util qw(refaddr);
use Exporter 'import';
our @EXPORT = qw(future);

sub future {
  my ($cb) = @_;
  my $future = __PACKAGE__->new;
  $cb->(sub {
      my ($obj, $err, @results) = @_;
      if ($err) {
        $future->fail_next_tick($err);
      } else {
        $future->done_next_tick($obj, @results);
      }
    }
  );
  return $future;
}

sub wait_ignore {
  my ($self) = @_;
  state %waiting;
  $waiting{refaddr($self)} = $self;
  $self->on_ready(sub {
    delete $waiting{refaddr($self)};
  });
}

1;
