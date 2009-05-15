package CPAN::Mini::Inject;

use strict;

use Env;
use Carp;
use LWP::Simple;
use File::Copy;
use File::Basename;
use CPAN::Checksums qw(updatedir);
use Compress::Zlib;
use CPAN::Mini;
use CPAN::Mini::Inject::Config;

=head1 NAME

CPAN::Mini::Inject - Inject modules into a CPAN::Mini mirror.

=head1 VERSION

Version 0.23

=cut

our $VERSION = '0.23';
our @ISA     = qw( CPAN::Mini );

=head1 SYNOPSIS

If you're not going to customize the way CPAN::Mini::Inject works, you
probably want to look at the mcpani command, instead.

    use CPAN::Mini::Inject;

    $mcpi=CPAN::Mini::Inject->new;
    $mcpi->parsecfg('t/.mcpani/config');

    $mcpi->add( module   => 'CPAN::Mini::Inject', 
                authorid => 'SSORICHE', 
                version  => ' 0.01', 
                file     => 'mymodules/CPAN-Mini-Inject-0.01.tar.gz' )

    $mcpi->writelist;
    $mcpi->update_mirror;
    $mcpi->inject;

=head1 DESCRIPTION

CPAN::Mini::Inject uses CPAN::Mini to build or update a local CPAN mirror
then adds modules from your repository to it, allowing the inclusion
of private modules in a minimal CPAN mirror. 

=head2 Methods

Each method in CPAN::Mini::Inject returns a CPAN::Mini::Inject object which
allows method chaining. For example:

    my $mcpi=CPAN::Mini::Inject->new;
    $mcpi->parsecfg
         ->update_mirror
         ->inject;

=over 4

=item new()

Create a new CPAN::Mini::Inject object.

=cut

sub new {
  return bless
   { config_class => 'CPAN::Mini::Inject::Config' },
   $_[0];
}

=item config_class( [CLASS] )

Returns the name of the class handling the configuration. 

With an argument, it sets the name of the class to handle
the config. To use that, you'll have to call it before you
load the configuration.

=cut

sub config_class {
  my $self = shift;

  if ( @_ ) { $self->{config_class} = shift }

  $self->{config_class};
}

=item config

Returns the configuration object. This object should be from
the class returned by C<config_class> unless you've done something
wierd.

=cut

sub config {
  my $self = shift;

  if ( @_ ) { $self->{config} = shift }

  $self->{config};
}

=item loadcfg( [FILENAME] )


This is a bridge to CPAN::Mini::Inject::Config's loadconfig. It sets the
filename for the configuration, or uses one of the defaults.

=cut

sub loadcfg {
  my $self = shift;

  unless ( $self->{config} ) {
    $self->{config} = $self->config_class->new;
  }

  $self->{cfgfile} = $self->{config}->load_config( @_ );

  return $self;
}

=item parsecfg()

This is a bridge to CPAN::Mini::Inject::Config's parseconfig.

=cut

sub parsecfg {
  my $self = shift;

  unless ( $self->{config} ) {
    $self->config( $self->config_class->new );
  }

  $self->config->parse_config( @_ );

  return $self;
}

=item site( [SITE] )
	
Returns the CPAN site that CPAN::Mini::Inject chose from the 
list specified in the C<remote> directive.

=cut

sub site {
  no warnings;
  my $self = shift;

  if ( @_ ) { $self->{site} = shift }

  $self->{site} || '';
}

=item testremote()


Test each site listed in the remote parameter of the config file by performing
a get on each site in order for authors/01mailrc.txt.gz. The first site to
respond successfully is set as the instance variable site.

	print "$mcpi->{site}\n"; # ftp://ftp.cpan.org/pub/CPAN


C<testremote> accepts an optional parameter to enable verbose mode.

=cut

sub testremote {
  my $self    = shift;
  my $verbose = shift;

  $self->site( undef ) if $self->site;

  $ENV{FTP_PASSIVE} = 1 if ( $self->config->get( 'passive' ) );

  foreach my $site ( split( /\s+/, $self->config->get( 'remote' ) ) ) {

    $site .= '/' unless ( $site =~ m/\/$/ );

    print "Testing site: $site\n" if ( $verbose );

    if ( get( $site . 'authors/01mailrc.txt.gz' ) ) {
      $self->site( $site );

      print "\n$site selected.\n" if ( $verbose );
      last;
    }
  }

  croak "Unable to connect to any remote site" unless $self->site;

  return $self;
}

=item update_mirror()

This is a subclass of CPAN::Mini.

=cut

sub update_mirror {
  my $self    = shift;
  my %options = @_;

  croak 'Can not write to local: ' . $self->config->get( 'local' )
   unless ( -w $self->config->get( 'local' ) );

  $ENV{FTP_PASSIVE} = 1 if $self->config->get( 'passive' );

  $options{local}     ||= $self->config->get( 'local' );
  $options{trace}     ||= 0;
  $options{skip_perl} ||= $self->config->get( 'perl' ) || 1;

  $self->testremote( $options{trace} )
   unless ( $self->site || $options{remote} );
  $options{remote} ||= $self->site;

  $options{dirmode} ||= oct( $self->config->get( 'dirmode' )
     || sprintf( '0%o', 0777 & ~umask ) );

  CPAN::Mini->update_mirror( %options );
}

=item add()


Add a new module to the repository. The add method copies the module file
into the repository with the same structure as a CPAN site. For example
CPAN-Mini-Inject-0.01.tar.gz is copied to MYCPAN/authors/id/S/SS/SSORICHE.
add creates the required directory structure below the repository.

=over 4

=item * module

The name of the module to add.

=item * authorid

CPAN author id. This does not have to be a real author id. 

=item * version

The modules version number.

=item * file

The tar.gz of the module.

=back

An example:


  add( module => 'Module::Name', 
       authorid => 'AUTHOR', 
       version => 0.01, 
       file => './Module-Name-0.01.tar.gz' );

=cut

sub add {
  my $self    = shift;
  my %options = @_;

  my $optionchk
   = _optionchk( \%options, qw/module authorid version file/ );

  croak "Required option not specified: $optionchk" if ( $optionchk );
  croak "No repository configured"
   unless ( $self->config->get( 'repository' ) );
  croak "Can not write to repository: "
   . $self->config->get( 'repository' )
   unless ( -w $self->config->get( 'repository' ) );

  croak "Can not read module file: $options{file}"
   unless ( -r $options{file} );

  my $modulefile = basename( $options{file} );
  $self->readlist unless ( exists( $self->{modulelist} ) );

  $options{authorid} = uc( $options{authorid} );
  $self->{authdir} = $self->_authordir( $options{authorid},
    $self->config->get( 'repository' ) );

  my $target
   = $self->config->get( 'repository' )
   . '/authors/id/'
   . $self->{authdir} . '/'
   . basename( $options{file} );

  copy( $options{file}, dirname( $target ) )
   or croak "Copy failed: $!";

  $self->_updperms( $target );

  push(
    @{ $self->{modulelist} },
    _fmtmodule(
      $options{module}, $self->{authdir} . "/$modulefile",
      $options{version}
    )
  );

  return $self;
}

=item inject()

Insert modules from the repository into the local CPAN::Mini mirror. inject
copies each module into the appropriate directory in the CPAN::Mini mirror
and updates the CHECKSUMS file.

Passing a value to C<inject> enables verbose mode, which lists each module
as it's injected.

=cut

sub inject {
  my $self    = shift;
  my $verbose = shift;

  my $dirmode = oct( $self->config->get( 'dirmode' ) )
   if ( $self->config->get( 'dirmode' ) );

  $self->readlist unless ( exists( $self->{modulelist} ) );

  my %updatedir;
  foreach my $modline ( @{ $self->{modulelist} } ) {
    my ( $module, $version, $file ) = split( /\s+/, $modline );
    my $target = $self->config->get( 'local' ) . '/authors/id/' . $file;
    my $source
     = $self->config->get( 'repository' ) . '/authors/id/' . $file;

    $updatedir{ dirname( $file ) } = 1;

    _mkpath( [ dirname( $target ) ], $dirmode );
    copy( $source, dirname( $target ) )
     or croak "Copy $source to " . dirname( $target ) . " failed: $!";

    $self->_updperms( $target );
    print "$target ... injected\n" if ( $verbose );
  }

  foreach my $dir ( keys( %updatedir ) ) {
    my $authdir = $self->config->get( 'local' ) . "/authors/id/$dir";

    updatedir( $authdir );
    $self->_updperms( "$authdir/CHECKSUMS" );
  }

  $self->updpackages;

  return $self;
}

=item updpackages()

Update the CPAN::Mini mirror's modules/02packages.details.txt.gz with the
injected module information.

=cut

sub updpackages {
  my $self = shift;

  my @modules = sort( @{ $self->{modulelist} } );

  my $packages = $self->_readpkgs;

  $packages = _uniq( $packages, \@modules );

  $self->_writepkgs( $packages );

  #  my $gzread = gzopen($cpanpackages,'rb')
  #    or croak "Cannot open local 02packages.details.txt.gz: $gzerrno";

#  my $inheader=1;
# my $gzwrite = gzopen($newpackages,'wb')
#   or croak "Cannot open repository 02packages.details.txt.gz: $gzerrno";
# my $package;
# while($gzread->gzreadline($package)) {
#   if($inheader) {
#     $inheader=0 unless(/\S/);
#     $gzwrite->gzwrite($_);
#     next;
#   }

  #   if(defined($modules[0]) && lc($modules[0]) lt lc($package)) {
  #     $gzwrite->gzwrite($modules[0]."\n");
  #     push(@packages,shift(@modules));
  #     shift(@modules);
  #     redo;
  #   }
  #   if(defined($modules[0]) && lc($modules[0]) eq lc($package)) {
  #     shift(@modules);
  #     next;
  #   }
  #   $gzwrite->gzwrite($_);
  #   push(@packages,$package);
  # }

  # $gzread->gzclose;
  # $gzwrite->gzclose;
  # copy($newpackages,$cpanpackages);
  # $self->_updperms($cpanpackages);

}

=item readlist()

Load the repository's modulelist.

=cut

sub readlist {
  my $self = shift;

  $self->{modulelist} = undef;

  return $self
   unless ( -e $self->config->get( 'repository' ) . '/modulelist' );
  croak 'Can not read module list: '
   . $self->config->get( 'repository' )
   . '/modulelist'
   unless ( -r $self->config->get( 'repository' ) . '/modulelist' );

  open( MODLIST, $self->config->get( 'repository' ) . '/modulelist' );

  while ( <MODLIST> ) {
    chomp;
    push( @{ $self->{modulelist} }, $_ );
  }
  close( MODLIST );

  return $self;
}

=item writelist()

Write to the repository modulelist.

=cut

sub writelist {
  my $self = shift;

  croak 'Can not write module list: '
   . $self->config->get( 'repository' )
   . "/modulelist ERROR: $!"
   unless ( -w $self->{config}{repository} . '/modulelist'
    || -w $self->{config}{repository} );

  return $self unless ( defined( $self->{modulelist} ) );

  open( MODLIST,
    '>' . $self->config->get( 'repository' ) . '/modulelist' );

  for ( sort( @{ $self->{modulelist} } ) ) {
    chomp;
    print MODLIST "$_\n";
  }
  close( MODLIST );

  $self->_updperms(
    $self->config->get( 'repository' ) . '/modulelist' );

  return $self;
}

sub _updperms {
  my ( $self, $file ) = @_;

  chmod( oct( $self->config->get( 'dirmode' ) ) & 06666, $file )
   if ( $self->config->get( 'dirmode' ) );

}

sub _optionchk {
  my ( $options, @list ) = @_;
  my @missing;

  foreach my $option ( @list ) {
    push( @missing, $option ) unless ( defined( $$options{$option} ) );
  }

  return join( ' ', @missing ) if ( @missing );
}

sub _authordir {
  my ( $self, $author, $dir ) = @_;

  foreach my $subdir (
    'authors', 'id',
    substr( $author, 0, 1 ),
    substr( $author, 0, 2 ), $author
   ) {
    $dir .= "/$subdir";
    unless ( -e $dir ) {
      mkdir $dir
       or croak "mkdir $subdir failed: $!";
      chmod( oct( $self->config->get( 'dirmode' ) ), $dir )
       if ( $self->config->get( 'dirmode' ) );

    }
  }

  return
     substr( $author, 0, 1 ) . '/'
   . substr( $author, 0, 2 ) . '/'
   . $author;
}

sub _mkpath {
  my $paths = shift;
  my $mode  = shift;

  foreach my $path ( @$paths ) {
    my $partpath;
    foreach my $subdir ( split( "/", $path ) ) {
      $partpath .= $subdir;
      if ( length( $subdir ) && not -e $partpath ) {
        mkdir $partpath;
        chmod( $mode, $partpath ) if ( $mode );
      }
      $partpath .= '/';
    }
  }
}

sub _fmtmodule {
  my ( $module, $file, $version ) = @_;

  $module .= ' ' while ( length( $module ) + length( $version ) < 38 );

  return "$module $version  $file";
}

sub _readpkgs {
  my $self = shift;

  my $gzread = gzopen(
    $self->config->get( 'local' ) .

     '/modules/02packages.details.txt.gz',
    'rb'
  ) or croak "Cannot open local 02packages.details.txt.gz: $gzerrno";

  my $inheader = 1;
  my @packages;
  my $package;

  while ( $gzread->gzreadline( $package ) ) {
    if ( $inheader ) {
      $inheader = 0 unless ( $package =~ /\S/ );
      next;
    }
    chomp( $package );
    push( @packages, $package );
  }

  $gzread->gzclose;

  return \@packages;
}

sub _writepkgs {
  my $self = shift;
  my $pkgs = shift;

  my $gzwrite = gzopen(
    $self->config->get( 'local' ) .

     '/modules/02packages.details.txt.gz',
    'wb'
   )
   or croak
   "Can't open local 02packages.details.txt.gz for writing: $gzerrno";

  $gzwrite->gzwrite( "File:         02packages.details.txt\n" );
  $gzwrite->gzwrite(
    "URL:          http://www.perl.com/CPAN/modules/02packages.details.txt\n"
  );
  $gzwrite->gzwrite(
    'Description:  Package names found in directory $CPAN/authors/id/'
     . "\n" );
  $gzwrite->gzwrite( "Columns:      package name, version, path\n" );
  $gzwrite->gzwrite(
    "Intended-For: Automated fetch routines, namespace documentation.\n"
  );
  $gzwrite->gzwrite( "Written-By:   CPAN::Mini::Inject $VERSION\n" );
  $gzwrite->gzwrite( "Line-Count:   " . scalar( @$pkgs ) . "\n" );
  # Last-Updated: Sat, 19 Mar 2005 19:49:10 GMT
  $gzwrite->gzwrite( "Last-Updated: " . _fmtdate() . "\n\n" );

  $gzwrite->gzwrite( "$_\n" ) for ( @$pkgs );

  $gzwrite->gzclose;

}

sub _uniq {
  my ( $list1, $list2 ) = @_;

  my %combined = map { $_, undef } @$list1, @$list2;

  my @fulllist = sort( keys( %combined ) );
  # return \@{sort(keys(%combined))};
  return \@fulllist;
}

sub _fmtdate {
  my @date = split( /\s+/, scalar( gmtime() ) );
  return "$date[0], $date[2] $date[1] $date[4] $date[3] GMT";
}

=back

=head1 SEE ALSO

L<CPAN::Mini>

=head1 AUTHOR

Shawn Sorichetti, C<< <ssoriche@coloredblocks.net> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-cpan-mini-inject@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll automatically
be notified of progress on your bug as I make changes.

=head1 COPYRIGHT AND LICENSE

Copyright 2004 Shawn Sorichetti, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;    # End of CPAN::Mini::Inject
