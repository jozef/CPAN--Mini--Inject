use Test::More tests => 3;

use CPAN::Mini::Inject;
use Env;

sub chkcfg {
  -r catfile( rootdir(), qw(usr local etc mcpani) )
   || -r catfile( rootdir(), qw(etc mcpani) );
}

my $prevhome;
if ( defined( $ENV{HOME} ) ) {
  $prevhome = $ENV{HOME};
  delete $ENV{HOME};
}

my $mcpanienv;
if ( defined( $ENV{MCPANI_CONFIG} ) ) {
  $mcpanienv = $ENV{MCPANI_CONFIG};
  delete $ENV{MCPANI_CONFIG};
}

my $mcpi = CPAN::Mini::Inject->new;

$mcpi->loadcfg( catfile( qw(t .mcpani config) ) );
is( $mcpi->{cfgfile}, catfile( qw(t .mcpani config) ) );

$ENV{HOME} = 't';
$mcpi->loadcfg;
is( $mcpi->{cfgfile}, catfile( qw(t .mcpani config) ) );

$ENV{MCPANI_CONFIG} = catfile( qw(t .mcpani config_mcpi) );
$mcpi->loadcfg;
is( $mcpi->{cfgfile}, catfile( qw(t .mcpani config_mcpi) ) );

# XXX add tests for /usr/local/etc/mcpani and /etc/minicpani

$ENV{MCPANI_CONFIG} = $mcpanienv if defined $mcpanienv;
$ENV{HOME}          = $prevhome  if defined $prevhome;
