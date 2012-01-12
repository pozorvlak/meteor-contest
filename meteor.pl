use 5.10.1;
use warnings;
use strict;
use integer;
use List::Util qw(min);

my ( $w, $h ) = ( 5, 10 );
my $dir_no = 6;
my ( $S, $E ) = ( $w * $h, 2 );
my $SE = $S + ( $E / 2 );
my $SW = $SE - $E;
my ( $W, $NW, $NE ) = ( -$E, -$SE, -$SW );

my %rd = ( $E => $NE, $NE => $NW, $NW => $W,  $W => $SW, $SW => $SE, $SE => $E );
my %fd = ( $E => $E,  $NE => $SE, $NW => $SW, $W => $W,  $SW => $NW, $SE => $NE );

my ( $board, $cti, $pieces ) = get_puzzle();
my @fps = get_footprints( $board, $cti, $pieces );
my @se_nh = get_senh( $board, $cti );

my %free        = map { $_ => undef } 0 .. @{$board} - 1;
my @curr_board  = ( -1 ) x @{$board};
my @pieces_left = 0 .. @{$pieces} - 1;
my @solutions   = ();
my $needed      = $ARGV[0];

solve( 0, \%free, \@pieces_left );
@solutions = sort @solutions;

say scalar @solutions, ' solutions found';
print_board( $solutions[0] );
print_board( $solutions[-1] );
print "\n";

sub rotate {
    return [ map { $rd{$_} } @{ $_[0] } ];
}

sub flip {
    return [ map { $fd{$_} } @{ $_[0] } ];
}

sub permute {
    my ( $ido, $r_ido ) = @_;

    my @ps = ( $ido );
    for my $r ( 0 .. $dir_no - 2 ) {
        push @ps, rotate( $ps[-1] );

        if ( @{$ido} ~~ @{$r_ido} ) {
            my $end = min( scalar @ps, int( $dir_no / 2 ) );
            @ps = @ps[ 0 .. $end - 1 ];
        }
    }

    push @ps, map { flip( $_ ) } @ps;

    return \@ps;
}

sub convert {
    my ( $ido ) = @_;

    my @out = ( 0 );
    for my $o ( @{$ido} ) {
        push @out, $out[-1] + $o;
    }

    my %unique;
    return [ grep { !$unique{$_}++ } @out ];
}

sub get_footprints {
    my ( $bd, $ct, $ps ) = @_;

    my @fp;
    foreach my $p ( 0 .. @{$ps} - 1 ) {
        foreach my $ci ( 0 .. @{$bd} - 1 ) {
            $fp[$ci]->[$p] = [];
        }
    }

    for my $c ( @{$bd} ) {
        for ( my $pi = 0 ; $pi < @{$ps} ; $pi++ ) {
            for my $pp ( @{ $ps->[$pi] } ) {
                my %f = ();
                for my $o ( @{$pp} ) {
                    if ( exists $ct->{ $c + $o } ) {
                        $f{ $ct->{ $c + $o } }++;
                    }
                }

                if ( keys %f == 5 ) {
                    push @{ $fp[ min( keys %f ) ]->[$pi] }, [ keys %f ];
                }
            }
        }
    }

    return @fp;
}

sub get_senh {
    my ( $bd, $ct ) = @_;

    my @se_nh2 = ();
    for my $c ( @{$bd} ) {
        my %f = ();
        for my $o ( $E, $SW, $SE ) {
            if ( exists $ct->{ $c + $o } ) {
                $f{ $ct->{ $c + $o } }++;
            }
        }

        push @se_nh2, \%f;
    }

    return @se_nh2;
}

sub get_puzzle {

    my @bd;
    for my $y ( 0 .. $h - 1 ) {
        for my $x ( 0 .. $w - 1 ) {
            push @bd, $E * $x + $S * $y + $y % 2;
        }
    }

    my %ct;
    for my $i ( 0 .. @bd - 1 ) {
        $ct{ $bd[$i] } = $i;
    }

    my @idos = (
        [ $E,  $E,  $E,  $SE ],
        [ $SE, $SW, $W,  $SW ],
        [ $W,  $W,  $SW, $SE ],
        [ $E,  $E,  $SW, $SE ],
        [ $NW, $W,  $NW, $SE, $SW ],
        [ $E,  $E,  $NE, $W ],
        [ $NW, $NE, $NE, $W ],
        [ $NE, $SE, $E,  $NE ],
        [ $SE, $SE, $E,  $SE ],
        [ $E,  $NW, $NW, $NW ]
    );

    my @ps;
    for my $p ( map { permute( $_, $idos[3] ) } @idos ) {
        push @ps, [ map { convert( $_ ) } @{$p} ];
    }

    return ( \@bd, \%ct, \@ps );
}

sub print_board {
    my ( $bd ) = @_;

    print "\n";
    for my $y ( 0 .. $h - 1 ) {
        for my $x ( 0 .. $w - 1 ) {
            print substr( $bd, $x + $y * $w, 1 ) . ' ';
        }

        print "\n";

        if ( $y % 2 == 0 ) {
            print ' ';
        }
    }
}

sub solve {
    my ( $i_min, $free, $pieces_left ) = @_;

    my $fp_i_cands = $fps[$i_min];

    for my $p ( @{$pieces_left} ) {
        my $fp_cands = $fp_i_cands->[$p];
        FOOTPRINT:
        for my $fpa ( @{$fp_cands} ) {

            for ( @{$fpa} ) {
                next FOOTPRINT if !exists $free->{$_};
            }

            $curr_board[$_] = $p for @{$fpa};

            if ( @{$pieces_left} > 1 ) {
                my %n_free = %{$free};
                delete $n_free{$_} for @{$fpa};

                my $n_i_min      = min( keys %n_free );
                my $intermediary = $se_nh[$n_i_min];

                my $any_free_is_in_intermediary = 0;
                for ( keys %n_free ) {
                    if ( exists $intermediary->{$_} ) {
                        $any_free_is_in_intermediary = 1;
                        last;
                    }
                }
                next if !$any_free_is_in_intermediary;

                my @n_pieces_left = grep { $_ != $p } @{$pieces_left};

                solve( $n_i_min, \%n_free, \@n_pieces_left );
            }
            else {
                my $s = join( '', @curr_board );
                push @solutions, $s;
                my $rs = reverse $s;
                push @solutions, $rs;

                return if @solutions >= $needed;
            }
        }

        return if @solutions >= $needed;
    }

    return;
}
