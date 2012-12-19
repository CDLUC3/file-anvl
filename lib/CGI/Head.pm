#

package CGI::Head;

use 5.006;
use strict;
use warnings;

our $VERSION;
$VERSION = sprintf "%d.%02d", q$Name: Release-1-06 $ =~ /Release-(\d+)-(\d+)/;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw();

our @EXPORT_OK = qw();

our %EXPORT_TAGS = (all => [ @EXPORT_OK ]);

our $headers_default = {
	'Status' => '200 OK',
	'Content-Type' => 'text/plain',
};

our $already_out_key = ':already_out';

# To support the CGI output protocol (tested with Apache).
#
sub new { my( $class, $headers ) =
	    (  shift,    shift );

	my $self = {};
	bless $self, $class;

	$headers ||= $headers_default;

	my ($key, $value);
	$self->{$key} = $value
		while ($key, $value) = each %$headers;

	defined($self->{$already_out_key}) or	# rare if caller defined so
		$self->setfuse;			# usually make ready to fire

	return $self;
}

# Add more headers, redefining any that are already defined.
#
sub add { my( $self, $headers ) =
	    ( shift,    shift );

	my ($key, $value);
	$self->{$key} = $value
		while ($key, $value) = each %$headers;
	return 1;
}

sub setfuse { my( $self ) = ( shift );

	$self->{$already_out_key} = 0;		# make ready to fire (again?)
	return 1;
}

# Destructive read of the header block; but it only pretends to destroy.
#
sub take { my( $self ) = ( shift );

	my $s = '';
	$self->{$already_out_key} and		# if the header block has fired
		return $s;			# any next time should be a dud

	my ($key, $value);

	($key ne $already_out_key and			# skip the reserved key
		$s .= "$key: $value\n")			# output key/value pair
				while			# iterate over all keys
		( ($key, $value)  =  each %{ $self } )	# note the random order
	;
	$s .= "\n";
	$self->{$already_out_key} = 1;		# don't do it again

	return $s;
}

1;

__END__

=head1 NAME

CGI::Head - trivial read-once stateful CGI header block

=head1 SYNOPSIS

 use CGI::Head;             # to import routines into a Perl script

 $ch = CGI::Head->new(      # make a header object, with optional HTTP
   { 'Status' => '200 OK',  # header block; if none supplied, this
     'Content-Type' =>      # default block makes any script output
        'text/plain', }     # browser-visible
 );

 $ch->add(                  # add or redefine headers, eg, Location
   { 'Status' =>            # example of changing a header
        401 unauthorized',
     'X-foo'  => 'Bar', }   # example of adding a user-defined header
 );

 $ch->take();               # get header as string and turn off

 $ch->setfuse();            # turn header block back on for next 'take'

=head1 DESCRIPTION

The B<CGI::Head> Perl module defines a trivial stateful object
representing a CGI header block.  It provides a way to output a CGI
header block exactly once at the front of an output stream when you're
not sure which of your script's output statements will fire first.

Headers can be defined on object creation, and added or modified later
using the I<add> method.  (A special pseudo-header, ":already_out", is
reserved to hold object state.)

The I<take> method returns the headers as a block and in random (hash)
order.  This method remembers if it has been called and only returns the
header block to the first caller.  Thereafter it returns the empty
string, unless and until the I<setfuse> method is called.

The default header block should make any script's text output from
behind a web server visible to a web browser.

=head1 EXAMPLE

Only one of these print statements will have a non-empty string returned
by I<take>.

  my $ch = CGI::Head->new();
  ...
  if ($foo) {
	...
  	print ($ch->take(), "foo branch\n");
	...
  }
  ...
  print ($ch->take(), "main branch\n");

=head1 HISTORY

This is a beta version.  It is written in Perl.

=head1 AUTHOR

John A. Kunze I<jak at ucop dot edu>

=head1 COPYRIGHT AND LICENSE

Copyright 2012 UC Regents.  Open source BSD license.

=cut
