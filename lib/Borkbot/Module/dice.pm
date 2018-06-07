package Borkbot::Module::dice;
use Moo;
use Borkbot::Module;
use List::Util;

#
# Usage
#
# .command SXdYTMZ
# There may be multiple expressions in each command.
#
# command is one of: roll iroll rolls
#   roll  - Normal.
#   iroll - Only display totals.
#   rolls - Only display individual rolls.
# S is an optional sign for adding die expressions together.
#   One of: - + *x /\
#     If the first segment starts with a sign, it will act as
#     if it was preceded by a '0'. This may be confusing.
# X is a positive decimal integer indicating the number of dice to roll.
# Y is a positive decimal integer indicating the number of sides per die.
#   It may optionally also be one of: % F
#     F - Fudge dice. These don't explode.
#     % - an alias for 100
# T is an optional indicator for roll type
#   One of: ' ., =
#     ' - High rolls explode (i.e., for each max roll, add a number
#         equal to a max roll to the total, and roll another die.)
#     , - Low rolls explode (i.e., for each roll of 1, subtract a number
#         equal to a max roll from the total, and roll another die.)
#     = - Low and high rolls explode.
# M is an optional sign for modifying the final total.
#   One of: - + *x /\ b w s
#   b - Takes the highest Z dice and uses them for the total, discarding others.
#   w - Takes the lowest Z dice and uses them for the total, discarding others.
# Z is a positive decimal integer indicating the number for the modifier.
#
# There is a limit of of 1000 dice per command, and of 1000 sides per die.
#
# Examples:
# <noober> .roll 1d6+3d6
# <sporksbot> noober: 1d6: 4; +3d6 10 [6, 3, 1]; <14>
# <noober> .roll 1d12' 1d6'
# <sporksbot> noober: 1d12': 23 [12, 11]; 1d6': 4
# <noober> .iroll
# <noober> .iroll 1d6+3d6
# <sporksbot> noober: 1d6: 4; +3d6: 10; <14>
# <noober> .iroll 1d12' 1d6'
# <sporksbot> noober: 1d12': 23; 1d6': 4
# <noober> .rolls 1d6+3d6
# <sporksbot> noober: 1d6 [4]; +3d6 [6, 3, 1]; <14>
# <noober> .rolls 1d12' 1d6'
# <sporksbot> noober: 1d12' [12, 11]; 1d6' [4]
# <noober> .roll 1d
# <sporksbot> Celti: 1d6: 3 [3]
# <noober> .roll d20
# <sporksbot> Celti: 1d20: 10 [10]

sub on_irc_privmsg {
  my ($self, $event) = @_;

  my $send_to = $event->reply_to;
  my $message = $event->msg;

    my ( $final, $total, @dice, @segments );
    my $showrolls  = 1;
    my $showtotals = 1;
    my $showdice   = 1;
    
    return 0 unless $message =~ /^\.(rolls|iroll|roll)/i;
    
    $showrolls  = 0 if $1 eq 'iroll';
    $showtotals = 0 if $1 eq 'rolls';
    
    ## SECRET UNDOCUMENTED FEATURES
    if ( $message =~ /^\.roll rick/i ) {
        $self->irc->privmsg( $send_to,
          "o/~ Never gonna give you up / never gonna let you down o/~" );
        return 1;
    } elsif ( $message =~ /^\.roll the bones/i ) {
        $self->irc->privmsg( $send_to,
          "o/~ So get out there and rock / and roll the bones o/~" );
        return 1;
    } elsif ( $message =~ /^\.roll drunk/i ) {
        $self->irc->privmsg( $send_to, $event->nick . " gets " . (int(rand(98))+1) . "¢ in beer-soaked change." );
        return 1;
    } elsif ( $message =~ /^\.(rolls|iroll|roll)$/i) {
        $message = "." . $1 . " 3d6";
    }
    
    unless (
        $message =~ / (?: [-+*x\/\\])?\s*
                      (?:\d+x)?
#                     (?>\d+) d (?:\d+|f|%)?
                      (?: (?>\d+)? d (?:\d+|f|%) | (?>\d+) d (?:\d+|f|%)? )
                      (?: ['.,=] )?
                      (?:[-+*x\/\\bw](?>\d+))?(?!d) /xi
      ) {
        $self->irc->privmsg( $send_to,
          '.{roll|iroll|rolls} [+-*/]#d#[\',=][+-*/bw #] '
          . '(For more detail, see http://beezhive.com/sporksbot/help.txt.)' );
        return 1;
    }
    
    @segments = ( $message =~ / ( (?: [-+*x\/\\])?\s*
                                (?:\d+x)?
#                               (?>\d+) d (?:\d+|f|%)?
                                (?: (?>\d+)? d (?:\d+|f|%) | (?>\d+) d (?:\d+|f|%)? )
                                (?: ['.,=] )?
                                (?:[-+*x\/\\bw](?>\d+))?(?!d) ) /xig
    ); # Take off every xig?
    
    #if ( @segments > 50 or $showrolls and @segments > 10 ) {
    if ( @segments > 50 ) {
        $self->irc->privmsg( $send_to, $event->nick
          . " rolled too many dice and some dropped off the table." );
        return 1;
    }
    
    for my $seg (@segments) {
        $seg =~ / ( [-+*x\/\\0] )?\s*
                  (?: (\d+) x )?
                  (\d+)? d (\d+|f|%)?
                  ( ['.,=] )?
                  (?: ([-+*x\/\\bw]) (\d*) )? /xi;
        
        my $die = {
            segmod   => $1,
            numrolls => defined($2) ? $2 : 1,
            numdice  => defined($3) ? $3 : 1,
            numsides => defined($4) ? $4 : 6,
            rolltype => $5,
            diemod   => $6,
            modval   => $7,
            fudge    => 0,
            rollsmade => 0,
        };
        
        $die->{numsides} = 100 if $die->{numsides} eq '%';
        
        if ( $die->{numsides} =~ /F/i ) {
            $die->{numsides} = 3;
            $die->{fudge}    = 1;
        }
        
        unless ( $die->{numdice} > 0 and $die->{numsides} > 0 ) {
            $self->irc->privmsg( $send_to, $event->nick
              . " makes a dice-rolling motion, but nothing happens." );
            return 1;
        }
        
        if ( defined $die->{rolltype} ) {
            if ($die->{rolltype} eq '=' and $die->{numsides} == 2 ) {
                $self->irc->privmsg( $send_to, $event->nick
                  . " flipped a coin and exploded." );
                return 1;
            } elsif ( $die->{numsides} < 2 ) {
                $self->irc->action( $send_to, "completed " . $event->nick
                  . "'s infinite loop in five seconds but isn't giving up the answer." );
                return 1;
            } elsif ( $die->{fudge} ) {
                $self->irc->action( $send_to, "ate " . $event->nick
                  . "'s fudge before it exploded." );
                return 1;
            }
        }
        
        $die->{diemod} = undef unless defined $die->{modval};
        
        $die->{numdice}  = 1000 if $die->{numdice} > 1000;
        $die->{numsides} = 1000 if $die->{numsides} > 1000;
        $die->{numrolls} = 50 if $die->{numrolls} > 50;
        
        for ($die->{rollsmade} = 0; $die->{rollsmade} < $die->{numrolls}; $die->{rollsmade}++) {
            roll_dice($die);
            push @dice, {%{$die}};
        }
    }
    
    if ( List::Util::sum( map $_->{numdice}, @dice ) > 1000 ) {
        $self->irc->privmsg( $send_to, $event->nick
          . " rolled too many dice and some dropped off the table." );
        return 1;
    }
    
    for my $die (@dice) {
        $die->{output} = ' ';
        
        if ($showdice) {
            $die->{output} .= $die->{segmod} if defined $die->{segmod};
            $die->{output} .= $die->{numdice} . 'd';
            $die->{output} .= $die->{fudge} ? 'F' : $die->{numsides};
            $die->{output} .= $die->{rolltype} if defined $die->{rolltype};
            $die->{output} .= $die->{diemod} . $die->{modval} if defined $die->{modval};
        }
        
        $die->{output} .= ': ' . $die->{total} if $showtotals;

        if ( ( $showrolls && @{ $die->{rolls} } ) or not $showtotals ) {
            $die->{output} .= ' [' . join( ", ", @{ $die->{rolls} } ) . ']';
        }
        
        if ( !defined $die->{segmod} or $die->{segmod} eq '+' ) {
            $total += $die->{total};
        }
        elsif ( $die->{segmod} eq '-' ) {
            $total -= $die->{total};
        }
        elsif ( $die->{segmod} eq '*' or $die->{segmod} eq 'x' ) {
            $total *= $die->{total};
        }
        elsif ( $die->{segmod} eq '/' or $die->{segmod} eq '\\' ) {
            $total = sprintf "%.2f", $total / $die->{total};
        }
    }

    $final = $event->nick . ':';
    $final .= join( ';', map( $_->{output}, @dice ) );

    $final .= '; Total: ' . $total if List::Util::first { defined($_->{segmod}) } @dice;
    
    if ( length($final) > 400 ) {
        $self->irc->privmsg( $send_to, $event->nick
          . " rolled too many dice and some dropped off the table." );
        return 1;
    }

    log_debug { $final };
    $self->irc->privmsg( $send_to, $final );
    return 1;
}

sub roll_dice {
    my $die = shift;

    $die->{rolls} = ();
    $die->{total} = 0;

    for ( my $i = 0 ; $i < $die->{numdice} ; $i++ ) {
        push @{ $die->{rolls} }, 1 + int rand $die->{numsides};
    }

    if ( defined $die->{rolltype} ) {
        if ( $die->{rolltype} eq '\'' ) { # Explode high
            foreach ( @{ $die->{rolls} } ) {
                push( @{ $die->{rolls} }, 1 + int rand $die->{numsides} )
                  if $_ == $die->{numsides};
            }
        } elsif ( $die->{rolltype} eq ',' || $die->{rolltype} eq '.' ) { # Explode low
            foreach ( @{ $die->{rolls} } ) {
                push( @{ $die->{rolls} }, 1 + int rand $die->{numsides} )
                  if ( $_ eq 1 );
                $_ = 0 - $die->{numsides} if ( $_ eq 1 );
            }
        } elsif ( $die->{rolltype} eq '=' ) { # Explode
            foreach ( @{ $die->{rolls} } ) {
                push( @{ $die->{rolls} }, 1 + int rand $die->{numsides} )
                  if ( $_ eq $die->{numsides} || $_ eq 1 );
                $_ = 0 - $die->{numsides} if ( $_ eq 1 );
            }
        }
    }

    @{ $die->{rolls} } = map $_ - 2, @{ $die->{rolls} } if $die->{fudge};

    $die->{diemod} = '' unless defined $die->{diemod};

    # Take best/worst n
    if ( lc( $die->{diemod} ) eq 'b' ) {
        @{ $die->{rolls} } = sort { $b <=> $a } @{ $die->{rolls} };
        $die->{modval} = @{ $die->{rolls} } if $die->{modval} > @{ $die->{rolls} };
        $die->{total} = List::Util::sum( @{ $die->{rolls} }[ 0 .. $die->{modval} - 1 ] );
    } elsif ( lc( $die->{diemod} ) eq 'w' ) {
        @{ $die->{rolls} } = sort { $a <=> $b } @{ $die->{rolls} };
        $die->{modval} = @{ $die->{rolls} } if $die->{modval} > @{ $die->{rolls} };
        $die->{total} = List::Util::sum( @{ $die->{rolls} }[ 0 .. $die->{modval} - 1 ] );
    } else {    # Regular case
        $die->{total} = List::Util::sum( @{ $die->{rolls} } );
    }

    if ( $die->{diemod} eq '+' ) {
        $die->{total} += $die->{modval};
    } elsif ( $die->{diemod} eq '-' ) {
        $die->{total} -= $die->{modval};
    } elsif ( $die->{diemod} eq '*' or lc( $die->{diemod} ) eq 'x' ) {
        $die->{total} *= $die->{modval};
    } elsif ( $die->{diemod} eq '/' or $die->{diemod} eq '\\' ) {
        $die->{total} = sprintf "%.2f", $die->{total} / $die->{modval};
    }
}

1;
