package Borkbot::Logger;
use strict;
use warnings;

use Log::Dispatch;
use Log::Dispatch::File;
use Log::Dispatch::Screen;
use POSIX qw(strftime);

use base 'Log::Contextual';

our $package;

our $logger = Log::Dispatch->new(
  outputs => [ 
    # Early logging before config is loaded
    [ 'Screen', name => 'stderr', min_level => 'info', newline => 1 ],
  ],
  callbacks => sub {
    my %msg = @_;
    chomp($msg{message});
    return strftime("%Y-%m-%d %H:%M:%S ", localtime) . "[\U$msg{level}\E $package] $msg{message}";
  },
); 

sub arg_default_logger { $_[1] || sub {
    $package = $_[0];
    $logger;
  }
}
sub arg_levels { $_[1] || [qw(debug info warning error critical)] }
sub default_import { qw(:log :dlog) }

sub set_logfile {
  my ($config) = @_;

  $logger->remove('logfile');
  if (!$config->{enabled}) {
    return;
  }

  $logger->add(
    Log::Dispatch::File->new(
      name => 'logfile',
      filename => $config->{filename} || 'borkbot.log',
      min_level => $config->{level} || 'info',
      newline => 1,
    )
  );
}

sub set_stderr {
  my ($config) = @_;

  $logger->remove('stderr');
  if (!$config->{enabled}) {
    return;
  }

  $logger->add(
    Log::Dispatch::Screen->new(
      name => 'stderr',
      min_level => $config->{level} || 'info',
      newline => 1,
    )
  );
}

1;

