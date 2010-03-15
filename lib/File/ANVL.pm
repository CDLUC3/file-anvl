package File::ANVL;

use 5.006;
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

my $anvl_mode = ANVL;

our $VERSION;
$VERSION = sprintf "%d.%02d", q$Name: Release-0-16 $ =~ /Release-(\d+)-(\d+)/;

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

our @EXPORT = qw(
	anvl_fmt anvl_recsplit anvl_rechash anvl_valsplit
	anvl_name_naturalize anvl_encode anvl_decode
	om_plain om_anvl om_xml
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
# xxx need anvl_fmt_{value,sval,rval,aval} ??
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
sub anvl_recsplit { my( $record, $r_elems, $strict )=@_;

	! defined($record) and
		return "needs an ANVL record";
	ref($r_elems) ne "ARRAY" and
		return "2nd arg must reference an array";

	my $strict_default = 0;
	! defined($strict) and
		$strict = $strict_default;

	$_ = $record;
	s/^\s*//; s/\s*$//;		# trim both ends

	/\n\n/ and
		return "record should have no internal blank line(s)";
	# xxx adjust regexp for ANVLR
	! /^[^\s:][\w 	]*:/ and	# match against first element
		return "well-formed record begins with a label and colon";

	$anvl_mode ne ANVLR and
		s/^#.*\n//gm;		# remove comments plus final \n

	# If we're not in strict parse mode, correct for common error
	# where continued value is not indented.  We can pretty safely
	# assume a continued value if a line is flush left and contains
	# no colon at all.
	# 
	# This next substitution match needs to be multi-line to avoid
	# more explicit looping.
	#
	# XXX there's probably a more efficient way to do this.
	my $msg = "";
	my $indented = s/^([^\s:][^:]*)$/ $1/gm;
	if ($indented) {
		$strict and
			(@$r_elems = undef),
			return "error: $indented unindented value line(s)";
		$msg = "warning: indenting $indented value line(s)";
	}
	# if we get here, assume standard continuation lines, and join them
	# (GRANVL style)
	#
	s/\n\s+/ /g;
	# XXX should have a newline-preserving form of parse?

	# Split into array element pairs.  Toss first "false" split.
	# xxx buggy limited patterns, how not to match newline

	# This is the critical splitting step.
	# splits line beginning  ..... xxx
	#
	(undef, @$r_elems) = split /\n*^([^\s:][\w 	]*):\s*/m;

	return $msg;
}

# ANVL value splitter
# returns empty string on success or string beginning "warning:..."
# r_svals is reference to an array that will be filled upon return
sub anvl_valsplit { my( $value, $r_svals )=@_;

	! defined($value) and
		return "needs an ANVL value";
	ref($r_svals) ne "ARRAY" and
		return "2nd arg must reference an array";

	#xxx print "r_svals=$r_svals\n";
	#xxx print "value=$value\n";
	my $warning = "";		# xxx used?
	#my $ret_subvalues = \$_[1];

	# Assume value is all on one line and split it.
	#my @svals = split /\|/, $value;
	@$r_svals = split /\|/, $value;
	#$_[1] = \@svals;
	$_ = [ split(/;/, $_) ]		# create array of arrays
		for (@$r_svals);
		#xxxprint("svals=", join(", ", @$_), "\n")	for (@$r_svals);

	# xxxx need to look for all 3 levels:  (change spec)
	# XXXXXXX  value ::= one or more svals (sval1 | sval2 | ...)
	# XXXXXXX  sval ::= one or more rvals (rval1 ; rval2 ; ...)
	# XXXXXXX  rval ::= one or more qvals (qval1 (=) qval2 (=) ...)
	#   where s=sub, r=repeated, q=equivalent
	# XXXXXXX  or ?? rval ::= one or more avals (aval1 (=) aval2 (=) ...)
	return $warning ? "warning: $warning" : "";
}

# Create record hash, elem is key, value is value
#
sub anvl_rechash { my( $record, $r_hash, $strict )=@_;

	! defined($record) and
		return "needs an ANVL record";
	ref($r_hash) ne "HASH" and
		return "2nd arg must reference a hash";

	my $msg = "";
	my @elems;
	($msg = anvl_recsplit($record, \@elems, $strict)) and
		return "anvl_recsplit: $msg";

	my ($name, $value);
	while (1) {
		$name = shift @elems;
		last	unless defined $name; 	# nothing left
		$value = shift @elems;
		if (defined $$r_hash{$name}) {

			# XXXXXxxxx make adding a value policy-driven, eg,
			# "add" could mean (a) replace, (b) push on end array,
			# (c) push on start of array, (d) string concatenation,
			# (d) error.
			# xxx should anvl_rechash save line numbers?
			# xxx should anvl_recsplit save line numbers?

			my $v = $$r_hash{$name};	# add to current
			$v = [ $v ]		# make an array if currently
				unless ref $v;	# there's only one value
			push @$v, $value;
		}
		else {
			$$r_hash{$name} = $value;	# 1st value (non-array)
		}
	}
	return $msg;
}

# [ !"#\$%&'\(\)\*\+,/:;<=>\?@\[\\\]\|\0]
our %anvl_decoding = (

	'sp'  =>  ' ',		# decodes to space (0x20)
	'ex'  =>  '!',		# decodes to ! (0x21)
	'dq'  =>  '"',		# decodes to " (0x22)
	'ns'  =>  '#',		# decodes to # (0x23)
	'do'  =>  '$',		# decodes to $ (0x24)
	'pe'  =>  '%',		# decodes to % (0x25)
	'am'  =>  '&',		# decodes to & (0x26)
	'sq'  =>  "'",		# decodes to ' (0x27)
	'op'  =>  '(',		# decodes to ( (0x28)
	'cp'  =>  ')',		# decodes to ) (0x29)
	'as'  =>  '*',		# decodes to * (0x2a)
	'pl'  =>  '+',		# decodes to + (0x2b)
	'co'  =>  ',',		# decodes to , (0x2c)
	'sl'  =>  '/',		# decodes to / (0x2f)
	'cn'  =>  ':',		# decodes to : (0x3a)
	'sc'  =>  ';',		# decodes to ; (0x3b)
	'lt'  =>  '<',		# decodes to < (0x3c)
	'eq'  =>  '=',		# decodes to = (0x3d)
	'gt'  =>  '>',		# decodes to > (0x3e)
	'qu'  =>  '?',		# decodes to ? (0x3f)
	'at'  =>  '@',		# decodes to @ (0x40)
	'ox'  =>  '[',		# decodes to [ (0x5b)
	'ls'  =>  '\\',		# decodes to \ (0x5c)
	'cx'  =>  ']',		# decodes to ] (0x5d)
	'vb'  =>  '|',		# decodes to | (0x7c)
	'nu'  =>  "\0",		# decodes to null (0x00)
);

our %anvl_encoding;

# xxxxx handle these separately
#	# XXXX remove %% from erc/anvlspec?
#	'%'   =>  '%pe',	# decodes to % (0x25)  xxxx do this first?
#	'_'   =>  '',		# a non-character used as a syntax shim
#	'{'   =>  '',		# a non-character that begins an expansion block
#	'}'   =>  '',		# a non-character that ends an expansion block

# Takes a single arg.
sub anvl_decode {

	$_ = shift @_ || "";
	s/\%([_{}])//g;		# xxx ???
	s/\%\%/\%pe/g;		# xxx ??? xxxx???
	# decode %XY where XY together don't form a valid pair of hex digits
	s/\%([g-z][a-z]|[a-z][g-z])/$anvl_decoding{$1}/g;
	return $_;
}

sub anvl_encode { my( $s )=@_;
	
	# XXXX just define this in the module??
	unless (defined %anvl_encoding) {	# one-time definition
		# This just defines an inverse mapping so we can encode.
		$anvl_encoding{$anvl_decoding{$_}} = $_
			for (keys %anvl_decoding);
	}
	$s =~
	  s/([ !\"#\$\%&'\(\)\*\+,\/:;<=>\?@\[\\\]\|\0])/\%$anvl_encoding{$1}/g;
	return $s;
}

# return $name in natural word order, using ANVL inversion points
# XXXXXXXXX change spec to "final ,"
sub anvl_name_naturalize { my( $name )=@_;

	($_ = $name) ||= "";
	/^\s*$/			and return $name;	# empty
	s/,+\s*$//		or  return $name;	# doesn't end in ','
	s/^(.*),\s*(.*)$/$2 $1/;
	return $_;
}

# Output Multiplexer Routines

sub om_plain { my( $mode, $name, $value, $attribute, @other )=@_;

	return 1			# don't print comments
		if ($mode eq NOTE);
	# if we get here, we have a non-comment (DATA)
	# xxx ignoring attribute and other
	return $value . "\n";
}

sub om_anvl { my( $mode, $name, $value, $attribute, @other )=@_;

	return "# " . anvl_fmt($name, $value)
		if ($mode eq NOTE);
	# if we get here, we have a non-comment (DATA)
	# xxx ignoring attribute and other
	return anvl_fmt($name, $value);
}

sub om_xml { my( $mode, $name, $value, $attribute, @other )=@_;

	# xxx mostly untested code
	# xxx need to escape before embedding
	#
	return "<!-- $name, $value -->\n"
		if ($mode eq NOTE);
	# if we get here, we have a non-comment (DATA)
	# xxx ignoring attribute and other
	return "<$name>$value</$name>\n";
}

## extra newline version of om()
#sub oml { my( $format, $mode, $name, $value, $attribute, @other )=@_;
#
#	my $ret = om($mode, $name, $value, $attribute, @other);
#	return $ret	if ! $ret;
#	return (print "\n");
#}

1;

__END__

=head1 NAME

File::ANVL - routines to support A Name Value Language

=head1 SYNOPSIS

 use File::ANVL;        # to import routines into a Perl script

 $elem = anvl_fmt(      # format ANVL element, wrapping to 72 cols;
         $label,        # $label to appear to left of colon (:)
         $string );     # $string to appear to right of colon

 anvl_recsplit(         # split record into array of name-value pairs;
         $record,       # input record; arg 2 is reference to returned
         $r_elems,      # array; optional arg 3 (default 0) requires
         $strict );     # properly indented continuation lines

 anvl_valsplit(         # split ANVL value into an array of subvalues
         $value,        # input value; arg 2 is reference to returned
         $r_svals );    # array of arrays of returned values

 anvl_rechash(          # split ANVL record into hash of elements
         $record,       # input record; arg 2 is reference to returned
         $r_hash,       # hash; a value is scalar, or array of scalars
         $strict );     # if more than one element shares its name

 anvl_decode( $str );   # ANVL-decode string

 anvl_encode( $str );   # ANVL-encode string
        
 anvl_name_naturalize(  # convert name from sort-friendly to natural
         $name );       # word order using ANVL inversion points

=head1 DESCRIPTION

This is brief documentation for the B<ANVL> Perl module, with
support for representing data or metadata values in the ANVL format.
ANVL (A Name Value Language) is label-colon-value format similar
to email headers.

The C<anvl_fmt()> function returns a plain text string wrapped to 72
colums in label-colon-value format) representing an anvl element.  It
trims whitspace but preserves internal newlines.  In an upcoming release
it will ANVL-encode characters that would otherwise prevent correct
parsing.  Here's an example of how to create an ERC with Dublin Kernel
metadata.

     $anvl_record = anvl_fmt("erc")
         . anvl_fmt("who", $creator)
         . anvl_fmt("what", $title)
         . anvl_fmt("when", $date)
         . anvl_fmt("where", $identifier)
         . "\n";    # 2nd newline in a row terminates ANVL record

The C<anvl_recsplit()> function splits an ANVL record into elements,
returning them via the array reference given as the second argument.  Each
returned element is a pair of elements: a name and a value.  An optional
third argument, if true (default 0), rejects unindented continuation
lines, a common formatting mistake.  This function returns the empty
string on success, or message beginning "warning: ..." or "error: ...".
Here's an example that extracts and uses the first returned element.

     ($msg = anvl_recsplit($record, $elemsref)
         and die "anvl_recsplit: $msg";  # report what went wrong
     print scalar($$elemsref), " elements found\n",
         "First element label is $$elemsref[0]\n",
         "First element value is $$elemsref[1]\n";

The C<anvl_valsplit()> function splits an ANVL value into sub-values 
(svals) and repeated values (rvals), returning them as an array of arrays
via the array reference given as the second argument.  The top-level of
the array represents svals and the next level represents rvals.  This
function returns the empty string on success, or message beginning
"warning: ..." or "error: ...".

The C<anvl_rechash()> function splits an ANVL record into elements,
returning them via the hash reference given as the second argument.  A
hash key is defined for each element name found.  Under that key is
stored the corresponding element value, or an array of values if more
than one occurrence of the element name was encountered.  This function
returns the empty string on success, or message beginning "warning: ..."
or "error: ...".

The C<anvl_decode()> function takes an ANVL-encoded string and returns it 
after converting encoded characters to the standard representaion (e.g.,
%vb becomes `|').  The C<anvl_encode()> function does the opposite.

The C<anvl_name_naturalize()> function takes an ANVL string (aval)
and returns it after inversion at any designated inversion points.
The input string will be returned if it does not end in a comma (`,').
For example,

     anvl_name_naturalize("Smith, Pat,");

returns "Pat Smith".

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

# XXXXX this really belongs with an ERC module!!

# ordered list of kernel element names
our @kernel_labels = qw(
	who
	what
	when
	where
	how
	why
);

# Convert ERC/ANVL to long, explicitly tagged form
# Harmless when applied to ERC/ANVL that is already in long form.
#
sub erc_anvl_longer { my( $erc )=@_;

	my (@elems, @svals, $msg, $name, $value);
	($msg = anvl_recsplit($erc, \@elems)) and
		return "error: anvl_recsplit: $msg";
	while (1) {
		$name = shift @elems;
		$value = shift @elems;
		return ""	unless defined $name; 	# nothing found
		last		if $name eq "erc";
	}
	# If we get an erc with no value, then the erc is already in long
	# form (maybe empty), so we just return it (for idempotence).
	#
	$value =~ /^\s*$/ and		# for valueless "erc" element
		return $erc;		# return the whole "erc" record

	($msg = anvl_valsplit($value, \@svals)) and
		return "error: anvl_valsplit: $msg";

	my $longer = anvl_fmt("erc");		# initialize
	foreach my $label (@kernel_labels) {
		my $sval = shift @svals;
		last		unless defined $sval;
		$longer .= anvl_fmt($label, join("; ", @$sval));
	}
	#foreach  xxxx get final et al.
	#scalar(@$r_vals) and
	#	$longer .= anvl_fmt("etal", join("; ", @$
	return $longer . "\n";;
}

# returns empty string on success, or message on error
# returns string result via 2nd arg, which should be a string
sub erc_anvl2erc_turtle { my( $erc, $rec )=@_;

	! defined($erc) || $erc !~ /^erc.*:/ and
		return "needs an ERC/ANVL record";
	scalar(@_) < 2 || ref($rec) ne "" and
		return "2nd arg should be string to receive converted record";
	my $r_rec = \$_[1];	# create better name for return string

	$erc = erc_anvl_longer($erc)		# canonicalize if needed
		if $erc =~ /^erc.*:\s*(\n\s+)*\S/;

	my ($msg, %rhash);
	($msg = anvl_rechash($erc, \%rhash)) and
		return $msg;

	# start turtle record
	#
	my $this = $rhash{where} || "";
	$$r_rec =
		"\@prefix erc: <http://purl.org/kernel/elements/1.1/>\n" .
		"\@prefix this: <$this>\n";

	# Loop through list of kernel terms and print what's there.
	my $first = "this: ";
	for (@kernel_labels) {
		defined $rhash{$_} and
			$$r_rec .= ($first ? $first : "      ") . "erc:$_ " .
				'"""' . $rhash{$_} . '"""' . ";\n",
			$first &&= "";		# erase first time through
	}
	return $msg;
}

# @prefix erc: <http://purl.org/kernel/elements/1.1/>.
# @prefix this: <http://www.ccel.org/g/gibbon/decline/>.
# this: erc:who "Gibbon, Edward";
#       erc:what "The Decline and Fall of the Roman Empire";
#       erc:when "1781";
#       erc:where "http://www.ccel.org/g/gibbon/decline/".

my %erc_terms = (
	'h10'	=> 'about-erc',
	'h12'	=> 'about-what',
	'h13'	=> 'about-when',
	'h14'	=> 'about-where',
	'h11'	=> 'about-who',
	'h15'	=> 'about-how',
	'h506'	=> 'contributor',
	'h514'	=> 'coverage',
	'h502'	=> 'creator',
	'h507'	=> 'date',
	'h504'	=> 'description',
	'c1'	=> 'ERC',
	'h0'	=> 'erc',		# eek, collision with next XXXX
	'h0'	=> 'dir_type',
	'v1'	=> ':etal',
	'h509'	=> 'format',
	'c2'	=> 'four h\'s',
	'h510'	=> 'identifier',
	'h602'	=> 'in',
	'h5'	=> 'how',
	'h512'	=> 'language',
	'c3'	=> 'metadata',
	'h30'	=> 'meta-erc',
	'h32'	=> 'meta-what',
	'h33'	=> 'meta-when',
	'h34'	=> 'meta-where',
	'h31'	=> 'meta-who',
	'v2'	=> ':none',
	'h601'	=> 'note',
	'v3'	=> ':null',
	'c4'	=> 'object',
	'h505'	=> 'publisher',
	'c5'	=> 'resource',
	'h513'	=> 'relation',
	'h515'	=> 'rights',
	'h511'	=> 'source',
	'h503'	=> 'subject',
	'h20'	=> 'support-erc',
	'h22'	=> 'support-what',
	'h23'	=> 'support-when',
	'h24'	=> 'support-where',
	'h21'	=> 'support-who',
	'c6'	=> 'stub ERC',
	'v4'	=> ':tba',
	'h501'	=> 'title',
	'h508'	=> 'type',
	'v5'	=> ':unac',
	'v6'	=> ':unal',
	'v7'	=> ':unap',
	'v8'	=> ':unas',
	'v9'	=> ':unav',
	'v10'	=> ':unkn',
	'h2'	=> 'what',
	'h3'	=> 'when',
	'h4'	=> 'where',
	'h1'	=> 'who',
);

# Returns an array of terms corresponding to args given as coded
# synonyms for Dublin Kernel elements, eg, csyn2dk('h1') -> 'who'.
#
sub csyn2dk {

	my (@ret, $code);

	for (@_) {
		# Assume an 'h' in front if it starts with a digit.
		#
		($code = $_) =~ s/^(\d)/h$1/;

		# Return a defined hash value or the empty string..
		#
		push @ret, defined($erc_terms{$code}) ?
			$erc_terms{$code} : "";
	}
	return @ret;
}

my %kernel = (
	0	=>  'dir_type',
	1	=>  'who',
	2	=>  'what',
	3	=>  'when',
	4	=>  'where',
);

#XXX need this any more?
sub num2dk { my( $number )=@_;

	return $kernel{$number}
		if (exists($kernel{$number})
			&& defined($kernel{$number}));
	return $number;
}
