#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Document::Cabinet' );
}

diag( "Testing Document::Cabinet $Document::Cabinet::VERSION, Perl $], $^X" );
