package Borkbot::Module::version;
use Moo;
use Borkbot::Module;
use experimental 'postderef';

sub get_version {
  my ($self, $cb) = @_;

  Mojo::IOLoop->subprocess(sub {
    open my $fh, '-|', qw(git rev-parse --short HEAD) or die "git rev-parse: $!";
    chomp(my $rev = <$fh>);
    close $fh;
    die "no rev" unless defined $rev;
    open $fh, '-|', qw(git name-rev --name-only HEAD) or die "git name-rev: $!";
    chomp(my $name = <$fh>);
    close $fh;
    return $rev unless defined $name;

    $name =~ s{^[^/]+/}{};
    return "$name ($rev)";
  }, sub {
    my ($subprocess, $err, $version) = @_;
    if ($err) {
      $err =~ s/\n\z//;
      log_warning { "getting version failed: $err" };
      $cb->("unknown version");
    } else {
      $cb->("Borkbot $version https://github.com/arodland/borkbot (core by hobbs, sporksbot by beez, contributions from various sporkers)");
    }
  });
}

sub get_modules {
  my ($self) = @_;
  return "Modules loaded: " . join(", ", sort keys $self->bot->modules->%*);
}

sub on_irc_privmsg {
  my ($self, $ev) = @_;
  if ($ev->msg =~ /^\.version\s*$/) {
    $self->get_version(sub {
      my ($version) = @_;
      $self->irc->privmsg($ev->reply_to, $version);
    });
    return 1;
  } elsif ($ev->msg =~ /^\.modules\s*$/) {
    $self->irc->privmsg($ev->reply_to, $self->get_modules);
    return 1;
  }
  return 0;
}

sub on_ctcp_version {
  my ($self, $ev) = @_;
  $self->get_version(sub {
    my ($version) = @_;
    $self->irc->nctcp($ev->reply_to, $version);
    $self->irc->nctcp($ev->reply_to, $self->get_modules);
  });
  return 1;
}

1;
