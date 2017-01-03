package Borkbot::Module::foo;
use Moo;
use Borkbot::Logger;

has 'bot' => (
  is => 'ro',
  weak_ref => 1,
);

sub BUILD {
  log_info { "bar!" }
}

1;
