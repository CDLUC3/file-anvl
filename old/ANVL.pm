package File::ANVL;

use 5.000000;
use strict;
use warnings;

# ANVL flavors
#
use constant ANVL	=> 1;
use constant ANVLR	=> 2;
use constant ANVLS	=> 3;

# output formats
#
use constant FMT_PLAIN	=> 1;
use constant FMT_ANVL	=> 2;
use constant FMT_XML	=> 3;
use constant FMT_RDF	=> 4;

# output modes
#
use constant DATA	=> 1;
use constant NOTE	=> 2;

my %kernel = (
	0	=>  'dir_type',
	1	=>  'who',
	2	=>  'what',
	3	=>  'when',
	4	=>  'where',
);

my $anvl_mode = ANVL;

# This is a magic routine that the Exporter calls for any unknown symbols.
#
sub export_fail { my( $class, @symbols )=@_;
	# XXX define ANVLR, ANVLS, (GR)ANVL*
	print STDERR "XXXXX\n";
	for (@symbols) {
		print STDERR "sym=$_\n";
	}
	#return @symbols;
	return ();
}

require Exporter;
our @ISA = qw(Exporter);

our $VERSION;
$VERSION = sprintf "%d.%02d", q$Name: Release-0-12 $ =~ /Release-(\d+)-(\d+)/;
our @EXPORT = qw(
	anvl_fmt anvl_split
	ANVL ANVLR ANVLS
	FMT_PLAIN FMT_ANVL FMT_XML FMT_RDF
	DATA NOTE
);
our @EXPORT_OK = qw(
);

my $debug = 0;			# default is off; to set use anvl_debug(1)

sub anvl_debug { my( $n )=@_;
	$debug = $n;
	return 1;
}

use Text::Wrap;
my $maxcols = 72;
$Text::Wrap::columns = $maxcols;
$Text::Wrap::huge = 'overflow';		# don't break long values

# Make an ANVL element.
#

# XXXXX allow $indent_string to be set ??
# XXXX allow many pairs of args??
# xxxx watch out to make sure label doesn't get wrapped
# returns undef on error
sub anvl_fmt { my( $label, $value )=@_;

	# Process label part
	#
	! defined($label) || ! $label and
		return undef;
	$_ = $label;
	s/^\s*//; s/\s*$//;	# trim both ends
	s/\s+/ /g;		# squeeze multiple \s to one space
	s/%/%%/g;		# to preserve literal %, double it
				# XXX must be decoded by receiver
	s/:/%3a/g;		# URL-encode all colons (%cn)
	$label = $_;

	# Process value part
	#
	$value ||= "";
	$_ = $value;
	my ($initial_newlines) = /^(\n*)/;	# save initial newlines
						# always defined, often ""
	# value after colon starts with either preserved newlines,
	#	a space, or (if no value) nothing
	my $value_start = $initial_newlines || ($value ? " " : "");

	# xxx is there a linear whitespace char class??
	#     problem is that \s includes \n
	s/^\s*//; s/\s*$//;	# trim both ends

	s/%/%%/g;		# to preserve literal %, double it
				# XXX must be decoded by receiver
	if ($anvl_mode eq ANVLS) {
		s/\|/%7c/g;	# URL-encode all vertical bars (%vb)
		s/;/%3b/g;	# URL-encode all semi-colons (%sc)
		# XXX what about others, such as (:...)
	};
	$value = $_;
	# xxx ERC-encode ERC structural delims ?

	# XXX why do 4 bytes (instead of 2) show up in wget??
	# # %-encode any chars that need it
	# my $except_re = qr/([\001-\037\177-\377])/; XXX needed any more?
	# $s =~ s/$except_re/ "%" . join("", unpack("H2", $1)) /ge;
	# fold lines longer than 72 chars and wrap with one tab's
	#    indention (assume tabwidth=8, line length of 64=72-8

	# wrap:  initial tab = "", subsequent tab = "\t"
	# append final newline to end the element
	#
	return wrap("", "\t",
		"$label:" . $value_start . $value) . "\n";
}

# returns empty string on success or string beginning "warning:..."
# third arg (0 or 1) optional
# elems is returned array of name value pairs
sub anvl_split { my( $record, $elems, $strict )=@_;

	! defined($record) and
		return "needs an ANVL record";
	#ref($_[1]) ne "ARRAY" and		# the $elems parameter
	#	return "elems parameter should reference an empty array";

	my ($name, $value, $warning);
	my $ret_elems = \$_[1];
	my @anvl_elem = ();
	my $strict_default = 0;

	! defined($strict) and
		$strict = $strict_default;

	$_ = $record;
	s/^\s*//; s/\s*$//;		# trim both ends

	/\n\n/ and
		return "record should have no internal blank line(s)";
	# xxx adjust regexp for ANVLR
	# xxx how to match against whitespace that's not a newline?
	! /^[^\s:][\w 	]*:/ and	# match against first element
		return "well-formed record begins with a label and colon";

	$anvl_mode ne ANVLR and
		s/^#.*$//gm;		# remove comment lines

	# If we're not in strict parse mode, correct for common error
	# where continued value is not indented.  We can pretty safely
	# assume a continued value if a line is flush left and contains
	# no colon at all.
	# 
	# This next substitution match needs to be multi-line to avoid
	# more explicit looping.
	#
	# XXX there's probably a more efficient way to do this.
	my $indented = s/^([^\s:][^:]*)$/ $1/gm;
	if ($indented) {
		$strict and
			return "$indented unindented value line(s)";
		$warning = "indenting $indented value line(s)";
	}
	# if we get here, assume standard continuation lines, and join them
	# (GRANVL style)
	#
	s/\n\s+/ /g;
	# XXX should have a newline-preserving form of parse?

	# Split into array element pairs.  Toss first "false" split.
	# xxx buggy limited patterns, how not to match newline
	(undef, @anvl_elem) = split /\n*([^\s:][\w 	]*):\s*/m;
	# xxx print "ae= ", join(", ", @anvl_elem), "\n";

	# return array reference, which persists after return xxx right?
	#
	$$ret_elems = \@anvl_elem;
	return (defined($warning) ? "warning: $warning" : "");
}

__END__

=head1 NAME

File::ANVL - routines to support A Name Value Language, version 0.1

=head1 SYNOPSIS

 use File::ANVL;           # to import routines into a Perl script

 $elem = anvl_fmt( $label, $string );
                            # Wraps text to 72 columns, appends newline
                            # to end the value.  Trims whitespace from
                            # $string but preserves initial newlines and
                            # internal newlines.

 # Example of anvl_fmt() to make an ERC with Dublin Kernel metadata.
 $anvl_record = anvl_fmt("erc")
     . anvl_fmt("who", $creator)
     . anvl_fmt("what", $title)
     . anvl_fmt("when", $date)
     . anvl_fmt("where", $identifier)
     . "\n";                # 2nd newline in a row terminates ANVL record

 anvl_split( $record,       # Splits ANVL record into an array of elems
             $elemsref,     # as name/value pairs.  Optional bpoolean 3rd
             $strict )      # arg rejects unindented continuation lines
                            # (default 0).  Returns empty string on
                            # success, or message beginning "warning:..."
                            # if a recoverable formatting problem was
                            # corrected.  A reference to array of broken
                            # out elements is returned through $elemsref.

 # Example use of anvl_split() to extract first element.
 ($msg = anvl_split($record, $elemsref)
     and die("anvl_split: $msg);        # report what went wrong
 print scalar($$elemsref), " elements found\n"
     "First element label is $$elemsref[0]\n",
     "First element value is $$elemsref[1]\n";

=head1 DESCRIPTION

This is very brief documentation for the B<ANVL> Perl module, which deals
with routines for representing data or metadata values in two very simple
forms.  ANVL (A Name Value Language) is label-colon-value format similar
to email headers.

The C<anvl_fmt()> function returns a plain text string (in
label-colon-value format) representing an anvl element.  Its main purpose
is to URL-encode (%-encode) the label and wrap lines for convenient
printing and screen viewing.  Newlines in the value are preserved.

=head1 SEE ALSO

A Name Value Language (ANVL)
	L<http://www.cdlib.org/inside/diglib/ark/anvlspec.pdf>

A Metadata Kernel for Electronic Permanence (PDF)
	L<http://journals.tdl.org/jodi/article/view/43>

=head1 HISTORY

This is an alpha version of ANVL tools.  It is written in Perl.

=head1 AUTHOR

John A. Kunze I<jak at ucop dot edu>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 UC Regents.  Open source Apache License, Version 2.

=head1 PREREQUISITES

Perl Modules: L<Text::Wrap>

Script Categories:

=pod SCRIPT CATEGORIES

UNIX : System_administration

=cut

sub anvl_oldfmt { my( $s )=@_;

	$s eq "" and		# return an empty string untouched (add no \n)
		return $s;
	#$s =~ s/\n/ /g;	# replace every \n with " " -- this case is
	#			# not expected, but would screw things up

	$s =~ s/^\s*//;		# trim initial whitespace
	$s =~ s/%/%%/g;		# to preserve literal %, double it
				# XXX must be decoded by receiver
	# xxx ERC-encode ERC structural delims ?

	# XXX why do 4 bytes (instead of 2) show up in wget??
	# # %-encode any chars that need it
	# $s =~ s/$except_re/ "%" . join("", unpack("H2", $1)) /ge;
	# fold lines longer than 72 chars and wrap with one tab's
	#    indention (assume tabwidth=8, line length of 64=72-8

	# wrap:  initial tab = "", subsequent tab = "\t"
	$s = wrap("", "\t", $s);
	return $s . "\n";		# append newline to end element
}

