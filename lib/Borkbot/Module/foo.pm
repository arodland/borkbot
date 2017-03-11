package Borkbot::Module::foo;
use Moo;
use Borkbot::Module;

sub on_irc_privmsg {
  my ($self, $ev) = @_;
  
  return 0 unless $ev->{msg} =~ /^\.foo\s*$/i;

  $self->irc->privmsg($ev->{reply_to}, "bar!");
  return 1;
}

1;
