use Test::More tests => 1;
use File::Spec::Functions;

BEGIN {
  use_ok( 'CPAN::Mini::Inject' );
}

diag( "Testing CPAN::Mini::Inject $CPAN::Mini::Inject::VERSION" );

# Setup for other tests

mkdir catfile( qw(t local WRITEREPO) );
open WRITEFILE, '>', catfile( qw(t local WRITEREPO modulelist) );
close WRITEFILE;
chmod 0222, catfile( qw(t local WRITEREPO modulelist) );
chmod 0555, catfile( qw(t read MYCPAN) );
chmod 0444, catfile( qw(t read MYCPAN modulelist) );
chmod 0444, catfile( qw(t read MYCPAN test-0.01.tar.gz) );
