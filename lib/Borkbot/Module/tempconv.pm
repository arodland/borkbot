package Borkbot::Module::tempconv;
use Moo;
use Borkbot::Module;

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  if($ev->msg =~ /^\.ftoc\s+(\-?[\d]+(\.[\d]+)?)/i) {
    my $temp = (5/9)*($1-32);
    $temp = sprintf("%.2f",$temp);
    $self->irc->privmsg($ev->reply_to, "$1 F = $temp C");
    return 1;
  }
  elsif($ev->msg =~ /^\.ftok\s+(\-?[\d]+(\.[\d]+)?)/i) {
    my $temp = (5/9)*($1-32) + 273.15;
    $temp = sprintf("%.2f",$temp);
    $self->irc->privmsg($ev->reply_to, "$1 F = $temp K");
    return 1;
  }
  elsif($ev->msg =~ /^\.ctof\s+(\-?[\d]+(\.[\d]+)?)/i) {
    my $temp = ((9/5)*$1) + 32;
    $temp = sprintf("%.2f",$temp);
    $self->irc->privmsg($ev->reply_to, "$1 C = $temp F");
    return 1;
  }
  elsif($ev->msg =~ /^\.ctok\s+(\-?[\d]+(\.[\d]+)?)/i) {
    my $temp = $1 + 273.15;
    $temp = sprintf("%.2f",$temp);
    $self->irc->privmsg($ev->reply_to, "$1 C = $temp K");
    return 1;
  }
  elsif($ev->msg =~ /^\.ktof\s+(\-?[\d]+(\.[\d]+)?)/i) {
    my $temp = ((9/5)*($1-273.15)) + 32;
    $temp = sprintf("%.2f",$temp);
    $self->irc->privmsg($ev->reply_to, "$1 K = $temp F");
    return 1;
  }
  elsif($ev->msg =~ /^\.ktoc\s+(\-?[\d]+(\.[\d]+)?)/i) {
    my $temp = $1 - 273.15;
    $temp = sprintf("%.2f",$temp);
    $self->irc->privmsg($ev->reply_to, "$1 K = $temp C");
    return 1;
  }

  return 0;
}

1;
