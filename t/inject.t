use Test::More tests => 8;

use CPAN::Mini::Inject;
use File::Path;
use File::Copy;
use File::Basename;
use Compress::Zlib;

rmtree( [ catfile( qw(t local MYCPAN modulelist) ) ], 0, 1 );
copy(
  catfile( qw(t local CPAN modules 02packages.details.txt.gz.bak) ),
  catfile( qw(t local CPAN modules 02packages.details.txt.gz) )
);

rmtree( [ catfile( qw(t local CPAN authors) ) ], 0, 1 );
mkdir( catfile( qw(t local MYCPAN) ) );

my $mcpi;
my $module
 = catfile( qw( S SS SSORICHE CPAN-Mini-Inject-0.01.tar.gz ) );

$mcpi = CPAN::Mini::Inject->new;
$mcpi->loadcfg( catfile( qw(t .mcpani config) ) )
 ->parsecfg->readlist->add(
  module   => 'CPAN::Mini::Inject',
  authorid => 'SSORICHE',
  version  => '0.01',
  file => catfile( qw(t/local/mymodules/CPAN-Mini-Inject-0.01.tar.gz) )
 )->writelist;

ok( $mcpi->inject, 'Copy modules' );
ok( -e catfile( qw(t local CPAN authors id), $module ),
  'Module file exists' );
ok( -e catfile( qw(t local CPAN authors id S SS SSORICHE CHECKSUMS) ),
  'Checksum created' );

SKIP: {
  skip "Not a UNIX system", 3 if $^O =~ /^MSWin/;
  is(
    ( stat( catfile( qw(t local CPAN authors id), $module ) ) )[2]
     & 07777,
    0664,
    'Module file mode set'
  );

  is(
    (
      stat(
        dirname( catfile( qw(t local CPAN authors id), $module ) )
      )
    )[2] & 07777,
    0775,
    'Author directory mode set'
  );

  is(
    (
      stat(
        catfile( qw(t local CPAN authors id S SS SSORICHE CHECKSUMS) )
      )
    )[2] & 07777,
    0664,
    'Checksum file mode set'
  );
}

my @goodfile = <DATA>;
ok(
  my $gzread = gzopen(
    catfile( qw(t local CPAN modules 02packages.details.txt.gz) ), 'rb'
  )
);

my @packages;
my $package;
while ( $gzread->gzreadline( $package ) ) {
  if ( $package =~ /^Written-By:/ ) {
    push( @packages, "Written-By:\n" );
    next;
  }
  if ( $package =~ /^Last-Updated:/ ) {
    push( @packages, "Last-Updated:\n" );
    next;
  }
  push( @packages, $package );
}

is_deeply( \@goodfile, \@packages );

unlink(
  catfile( qw(t local CPAN authors id S SS SSORICHE CHECKSUMS) ) );
unlink( catfile( qw(t local CPAN authors id), $module ) );
unlink( catfile( qw(t local MYCPAN modulelist) ) );
unlink( catfile( qw(t local CPAN modules 02packages.details.txt.gz) ) );
rmtree(
  [
    catfile( qw(t local CPAN authors) ), catfile( qw(t local MYCPAN) )
  ],
  0, 1
);

__DATA__
File:         02packages.details.txt
URL:          http://www.perl.com/CPAN/modules/02packages.details.txt
Description:  Package names found in directory $CPAN/authors/id/
Columns:      package name, version, path
Intended-For: Automated fetch routines, namespace documentation.
Written-By:
Line-Count:   6
Last-Updated:

Acme::Code::Police               2.1828  O/OV/OVID/Acme-Code-Police-2.1828.tar.gz
BFD                                0.31  R/RB/RBS/BFD-0.31.tar.gz
CPAN::Mini                         0.16  R/RJ/RJBS/CPAN-Mini-0.16.tar.gz
CPAN::Mini::Inject                 0.01  S/SS/SSORICHE/CPAN-Mini-Inject-0.01.tar.gz
CPAN::Nox                          1.02  A/AN/ANDK/CPAN-1.76.tar.gz
CPANPLUS                          0.049  A/AU/AUTRIJUS/CPANPLUS-0.049.tar.gz
