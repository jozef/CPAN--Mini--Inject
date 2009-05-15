use Test::More tests => 6;

use CPAN::Mini::Inject;

my $mcpi = CPAN::Mini::Inject->new;
$mcpi->loadcfg( catfile( qw(t .mcpani config) ) );
$mcpi->parsecfg;

is( $mcpi->{config}{local},      catfile( qw(t local CPAN) ) );
is( $mcpi->{config}{remote},     'http://localhost:8080' );
is( $mcpi->{config}{repository}, catfile( qw(t local MYCPAN) ) );

$mcpi = CPAN::Mini::Inject->new;
$mcpi->parsecfg( catfile( qw(t .mcpani config) ) );

is( $mcpi->{config}{local},      catfile( qw(t local CPAN) ) );
is( $mcpi->{config}{remote},     'http://localhost:8080' );
is( $mcpi->{config}{repository}, catfile( qw(t local MYCPAN) ) );
