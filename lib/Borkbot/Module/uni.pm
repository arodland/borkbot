package Borkbot::Module::uni;
# Based on App::uni by RJBS, which was CC0 licensed.

use Moo;
use Borkbot::Module;

use 5.10.0; # for \v
use Encode qw(encode_utf8);
use Text::ParseWords;
use Getopt::Long;
use List::Util qw(max);
use Unicode::GCString;
use charnames ();


my @uninames;
BEGIN {
  my $data = do 'unicore/Name.pl';
  @uninames = split /\cJ/, $data;
}

sub on_irc_privmsg {
  my ($self, $ev) = @_;

  return 0 unless $ev->msg =~ /^\.uni (.+)$/;
  my $cmdline = $1;

  my @lines = $self->run(shellwords($cmdline));

  if (!@lines) {
    @lines = ("No output.");
  }

  if (@lines > ($self->bot->config->{uni}{max_lines} || 7)) {
    my $uri = $self->bot->nopaste(text => join("\n", @lines));
    $self->irc->privmsg($ev->reply_to, $uri);
  } else {
    $self->irc->privmsg($ev->reply_to, $_) for @lines;
  }

  return 1;
}


use warnings;

sub _do_help {
  my $class = shift;

    return (
    ".uni SEARCH-TERMS...    - find codepoints with matching names or values",
    ".uni [-s] ONE-CHARACTER - print the codepoint and name of one character",
    ".uni -n SEARCH-TERMS... - find codepoints with matching names",
    ".uni -c STRINGS...      - print out the codepoints in a string",
    ".uni -u CODEPOINTS...   - look up and print hex codepoints",
    "Other switches:",
    "    -8                 - also show the UTF-8 bytes to encode\n"
  );
}

sub run {
  my ($class, @argv) = @_;

  my %opt;
  {
    my $exit;
    local @ARGV = @argv;
    GetOptions(
      "c" => \$opt{explode},
      "u" => \$opt{u_numbers},
      "n" => \$opt{names},
      "s" => \$opt{single},
      "8" => \$opt{utf8},
      "help|?" => \$opt{help},
    );
    @argv = @ARGV;
  }

  return $class->_do_help if $opt{help};

  my $n = grep { $_ } @opt{qw(explode u_numbers names single)};

  return $class->_do_help("ERROR: only one mode switch allowed!") if $n > 1;

  return $class->_do_help if ! @argv;

  my $todo  = $opt{explode}                       ? \&do_explode
            : $opt{u_numbers}                     ? \&do_u_numbers
            : $opt{names}                         ? \&do_names
            : $opt{single}                        ? \&do_single
            : @argv == 1 && length $argv[0] == 1  ? \&do_single
            :                                       \&do_dwim;

  $todo->(\@argv, \%opt);
}

sub do_single {
  my @chars    = grep { length } @{ $_[0] };
  if (my @too_long = grep { length > 1 } @chars) {
    die "some arguments were too long for use with -s: @too_long\n";
  }
  print_chars(\@chars, $_[1]);
}

sub do_explode {
  print_chars( explode_strings($_[0]), $_[1] );
}

sub explode_strings {
  my ($strings) = @_;

  my @chars;

  while (my $str = shift @$strings) {
    push @chars, split '', $str;
    push @chars, undef if @$strings;
  }

  return \@chars;
}

sub do_u_numbers {
  print_chars( chars_by_u_numbers($_[0]), $_[1] );
}

sub print_chars {
  my ($chars, $opt) = @_;

  my @ret;

  my @to_print = $opt->{utf8}
               ? (map {; [ $_ => defined && encode_utf8($_) ] } @$chars)
               : (map {; [ $_ ] } @$chars);

  my $width;
  if ($opt->{utf8}) {
    my $max_bytes = 0;
    for my $todo (@to_print) {
      $max_bytes = max($max_bytes, length $todo->[1]);
      last if $max_bytes == 4; # maximum ever
    }

    $width = 2 * $max_bytes + $max_bytes - 1;
  }

  for my $todo (@to_print) {
    my ($c, $u) = @$todo;

    unless (defined $c) { print "\n"; next }

    # U+25CC DOTTED CIRCLE
    my $c2 = Unicode::GCString->new(
      $c =~ /\p{COMBINING MARK}/ ? "\x{25CC}$c" : $c
    );
    my $l  = $c2->columns;

    # I'm not 100% sure why I need this in all cases.  It would make sense in
    # some, since for example COMBINING GRAVE beginning a line becomes its
    # own extended grapheme cluster (right?), but why does INVISIBLE TIMES at
    # the beginning of a line take up a column despite being printing width
    # zero?  The world may never know.  Until Tom tells me.
    # -- rjbs, 2014-10-04
    $l = 1 if $l == 0; # ???

    # Yeah, probably there's some insane %*0s$ invocation of printf to use
    # here, but... just no. -- rjbs, 2014-10-04
    (my $p = "$c2") =~ s/\v/ /g;
    $p .= (' ' x (2 - $l));

    my $chr  = ord($c);
    my $name = charnames::viacode($chr);
    my $utf8 = $opt->{utf8}
             ? (sprintf " - %${width}s",
                 join q{ }, map {; sprintf '%02X', ord } split //, $u)
             : '';

    push @ret, sprintf "%s- U+%05X%s - %s", $p, $chr, $utf8, $name;
  }
  return @ret;
}

sub chars_by_u_numbers {
  my ($points) = @_;
  my @chars = map {; /\A(?:u\+)?(.+)/; chr hex $1 } @$points;
  return \@chars;
}

sub do_names {
  my ($terms, $opt) = @_;

  print_chars( chars_by_name( $terms ), $opt );
}

sub chars_by_name {
  my ($input_terms, $arg) = @_;
  my @terms = map {; { pattern => s{\A/(.+)/\z}{$1} ? qr/$_/i : qr/\b$_\b/i } }
              @$input_terms;

  if ($arg && $arg->{match_codepoints}) {
    for (0 .. $#terms) {
      $terms[$_]{ord} = hex $input_terms->[$_]
        if $input_terms->[$_] =~ /\A[0-9A-Fa-f]+\z/;
    }
  }

  my @chars;

  my %seen;
  LINE: for my $line (@uninames) {
    my $i = index($line, "\t");
    next if rindex($line, " ", $i) >= 0; # no sequences

    my $name = substr($line, $i+1);
    my $ord  = hex substr($line, 0, $i);

    for (@terms) {
      next LINE unless $name =~ $_->{pattern}
                or     defined $_->{ord} && $_->{ord} == $ord;
    }

    my $c = chr hex substr $line, 0, $i;
    next if $seen{$c}++;
    push @chars, chr hex substr $line, 0, $i;
  }

  return \@chars;
}

sub smerge {
  my %splat = map {; $_ => 1 } map { @$_ } @_;
  return [ sort keys %splat ];
}

sub do_dwim {
  my ($argv, $opt) = @_;
  my $chars = chars_by_name($argv, { match_codepoints => 1 });
  print_chars($chars, $opt);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::Uni - command-line utility to find or display Unicode characters

=head1 VERSION

version 9.003

=head1 SYNOPSIS

    $ uni smiling face
    263A ☺ WHITE SMILING FACE
    263B ☻ BLACK SMILING FACE

    $ uni ☺
    263A ☺ WHITE SMILING FACE

    # Only on Perl 5.14+
    $ uni wry
    1F63C <U+1F63C> CAT FACE WITH WRY SMILE

=head1 DESCRIPTION

This module installs a simple program, F<uni>, that helps grepping through
the Unicode database included in the current Perl 5 installation.

For information on how to use F<uni> consult the L<uni> documentation.

=head1 NAME

App::Uni - Command-line utility to grep UnicodeData.txt

=head1 ACKNOWLEDGEMENTS

This is a re-implementation of a program written by Audrey Tang in Taiwan.  I
used that program for years before deciding I wanted to add a few features,
which I did by rewriting from scratch.

That program, in turn, was a re-implementation of a same-named program Larry
copied to me, which accompanied Audrey for years.  However, that program was
lost during a hard disk failure, so she coded it up from memory.

Thank-you, Larry, for everything. ♡

=head1 AUTHOR

Ricardo Signes <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE


Ricardo Signes has dedicated the work to the Commons by waiving all of his
or her rights to the work worldwide under copyright law and all related or
neighboring legal rights he or she had in the work, to the extent allowable by
law.

Works under CC0 do not require attribution. When citing the work, you should
not imply endorsement by the author.

=cut
