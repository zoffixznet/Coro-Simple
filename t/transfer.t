#!/usr/bin/perl6

use v6;

# a transfer function test

use Test;
use Coro::Simple;

plan 6;

sub transfer (&generator) {
    yield &generator; # 'transfer' is just a alias for 'yield'
}

# impure 'begin' function
# sub begin (&generator) {
#    my $transferred = generator;
#    $transferred = $transferred( ) while $transferred;
# }

# pure 'begin' function
multi begin (( )) { } # work around ? ...
multi begin (&generator) { begin generator( ) }

my $first;
my $second;
my $third;

my &ping = coro -> $msg {
    for ^3 -> $i {
	ok say "$msg -> $i";
	transfer $second;
    }
}

my &wtf = coro {
    for ^3 {
	say "\n" ~ "WTF?" ~ "\n\n";
	transfer $third;
    }
}

my &pong = coro -> $msg {
    for ^3 -> $i {
	ok say "$msg -> $i";
	transfer $first;
    }
}

$first  = ping "Ping!";
$second = wtf;
$third  = pong "Pong!";

begin $first; # begin the cycle with this generator

# a small / useful scheduler-like chunk
# (from $ping).map(&from).map: { &^generator( ) };

# for from $ping -> $coro {
#     for from $coro -> $next {
# 	$next( );
#     }
# }

# end of test