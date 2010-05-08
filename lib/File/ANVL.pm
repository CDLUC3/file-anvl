package File::ANVL;

use 5.006;
use strict;
use warnings;

use constant NL		=> "\n";

# ANVL flavors
#
use constant ANVL	=> 1;
use constant ANVLR	=> 2;
use constant ANVLS	=> 3;

our $VERSION;
$VERSION = sprintf "%d.%02d", q$Name: Release-0-26 $ =~ /Release-(\d+)-(\d+)/;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw();

our @EXPORT_OK = qw(
	anvl_recarray
	anvl_name_naturalize
	anvl_rechash anvl_valsplit
	erc_anvl_expand_array kernel_labels
	getlines trimlines
	anvl_opt_defaults anvl_decode anvl_om

	anvl_encode anvl_recsplit

	ANVL ANVLR ANVLS ANVLSH
);

our %EXPORT_TAGS = (all => [ @EXPORT_OK ]);

# All these symbols must be listed also in EXPORT_OK (?)
#
our @EXPORT_FAIL = qw(
	ANVL ANVLR ANVLS ANVLSH
);

our $anvl_mode = 'ANVL';		# default mode

# This is a magic routine that the Exporter calls for any unknown symbols.
#
sub export_fail { my( $class, @symbols )=@_;

	$anvl_mode = $_		for (@symbols);
	return ();
}

# Initialize or re-initialize options to factory defaults.
#
sub anvl_opt_defaults { return {

	# Input options
	#
	autoindent	=> 1,	# yes, fix recoverably bad indention
	comments	=> 0,	# no, don't parse comments
	elemsproc	=>	# to expand short form ERCs (if any)
		\&File::ANVL::erc_anvl_expand_array,
	elemsprocpat	=>	# no call from anvl_om if no match
		qr/^erc:/m,	# in rec; no call if set and matches
	};
}

# xxx change ercspec n2t.info -> n2t.net
# xxx     decide on good name for short form and long form ERC

sub getlines { my( $filehandle )=@_;

	my $rec = '';			# returned record
	my $s;				# next increment of input
	local $/ = NL.NL;		# a kind of "paragraph" input mode
					# $/ === $INPUT_RECORD_SEPARATOR
	# If $filehandle specified, use the Perl <$filehandle> idiom to
	# return next unit of input (normally a line, but here a para).
	#
	$filehandle ||= *ARGV;
	1 while (
		defined($s = <$filehandle>) and		# read and
			($rec .= $s),	# save everything, but stop
			$s !~ /\S/	# when we see substance
	);
	defined($s) or
		return $rec || undef;	# almost eof or real eof
	return $rec;

	# XXXX what happens when one file ends prematurely and
	# another begins? does last record for first file get
	# returned glued to beginning of first recond of 2nd file?
	# If more than one file, line numbers normally just accumulate.
	# We want to preserve line numbers within files, so we use this
	# next Perl idiom to cause $. (linenum) to be reset between files.
	#
	#close ARGV	if eof;		# reset line numbers between files
}

# args: record, reference to whitespace lines, reference to real record lines
# xxx replace \n with NL throughout
# returns undef when $rec trims to nothing (EOF)
sub trimlines { my( $rec, $r_wslines, $r_rrlines )=@_;

	# $rec might legitimately be undefined if called as
	# trimlines(getlines(), ...)
	#
	$rec ||= '';

	$rec =~ s/^(\s*)//;		# '*' guarantees $1 will be defined
	my $blanksection = $1;
	my @newlines;

	ref($r_wslines) eq 'SCALAR' and		# if given, define it
		$$r_wslines = scalar(@newlines = $blanksection =~ /\n/g);

	ref($r_rrlines) eq 'SCALAR' and		# if given, define it
		$$r_rrlines = scalar(@newlines = $rec =~ /\n/g);

	#$$r_rrlines = scalar($rec =~ /$/gm);	# xxx why doesn't this work?

	# At this point $r_wslines and $r_rrlines (if supplied) are safely
	# defined and ready for return.
	#
	$rec or			# empty record (but $r_wslines may be defined)
		return undef;	# signal eof-style return

	#$rec =~ /\n\n$/ and		# ok record ending -- this is
	#	return $rec;		# the usual  return
	#$rec =~ s/\n*$/\n\n/;		# normalize premature eof ending
	return $rec;
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

	local $_ = $record;
	s/^\s*//; s/\s*$//;		# trim both ends
	/\n$/	or s/$/\n/;		# normalize end of record to \n

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
	s/\n$//;			# strip final \n
	(undef, @$r_elems) = split /\n*^([^\s:][\w 	]*):\s*/m;

	return $msg;
}

# xxxxxxxx respond to 'comments' (def. off), 'autoindent' (def. on),
#   'anvlr' (def. off), 'granvl' ?

# returns "" on success, or "error: ..." or "warning: ..."

sub anvl_recarray { my( $record, $r_elems, $linenum, $o )=@_;

	! defined($record) and
		return "error: no input record";
	ref($r_elems) ne "ARRAY" and
		return "error: 2nd arg must reference an array";

	# Note: this input $linenum is pure digits, while $lineno on
	# output is a combination of digits and type (':' or '#')
	#
	defined($linenum)	or $linenum = 1;
	$linenum =~ /\D/ and
		return "error: 3rd arg ($linenum) must be a positive integer";
	$o ||= anvl_opt_defaults();
	ref($o) ne "HASH" and
		return "error: 4th arg must reference a hash";

	local $_ = $record;	# localizing $_ prevents modifying global $_

	s/^\s*//; s/\s*$//;		# trim both ends
	/\n$/	or s/$/\n/;		# normalize end of record to \n
	#s/\n?$/\nEOR:/;	# whether record ends in \n or not, normalize
	#		# end of record to \nEOR: (note no \n after \nEOR:)

	# Reject some malformed cases.
	#
	/\n\n/ and
		return "error: record should have no internal blank line(s)";
	# xxx adjust regexp for ANVLR
	/^[^\s:][\w 	]*:/m or	# match against first element
		return "error: record ($_) should begin with a label and colon";

	# Any other unindented line not containing a colon will either
	# cause an error or will be automatically indented.

	# xxx what about $anvl_mode ne ANVLR and??

	# remove comments unless 'comments' is in effect
	$$o{comments} or		# default is to remove comments
		s/^#.*\n//gm;		# up to and including final \n

	s/^/ $linenum++ . ":" /gem;	# put a line number on each line

	# Now put a pseudo-element name '#:' on each comment (if any) and
	# change first ':' separator to '#' for positive identification.
	# Eg, '# foo' on line 3 becomes '3##:# foo', which conforms to
	# the eventual split pattern we rely on (at end).

#split /\n*^(\d+[:#])(?:(#):#|([^\s:][^:]*):\s*)/m
	s/^(\d+):#/$1##:/gm;	
	#            ^^^
	#            123
	# 1=separator, 2=pseudo-name, 3=original value minus '#' starts after :

	my $msg = "";			# default return message

	# If we're not in strict parse mode, correct for common error
	# where continued value is not indented.  We can pretty safely
	# assume a continued value if a line is flush left and contains
	# no colon at all.
	# 
	# This next substitution match is multi-line to avoid explicit
	# looping (yyy is this an efficient way to do it?).  It indents
	# by one space any line starting without a space or colon and
	# that has no instance of a colon until end of line.
	#
	my $indented = s/^(\d+:)([^\s:][^:]*)$/$1 $2/gm;
	if ($indented) {
		unless ($$o{autoindent}) {
			@$r_elems = undef;
			return "error: $indented unindented value line(s)";
		}
		$msg = "warning: indenting $indented value line(s)";
	}

	# Now we join the (normalized) continuation lines (GRANVL style)
	# so each element-value pair is on one line.  The + in [ \t]+ is
	# very important; we can't use \s+ here because \s matches a \n.
	#
	s/\n\d+:[ \t]+/ /g;
	#s/\n\d+:\s+/ /g;
	# XXX should we have a newline-preserving form of parse?

	# Get rid of initial whitespace from all non-comment GRANVL values.
	s/^(\d+:[^\s:][^:]*:)[ \t]+/$1/gm;

	# Split into array of element pairs.  Toss first "false" split.
	# xxx buggy limited patterns, how not to match newline

	# This is the critical splitting step.
	# splits line beginning  ..... xxx
	#
	s/\n$//;			# strip final \n
	@$r_elems = ("ANVL", "beta",	# third elem provided by
		# unneeded first element resulting from the split

		split /\n*^(\d+[:#])([^\s:][^:]*):/m

	);
	#(undef, @$r_elems) = split /\n*^([^\s:][\w 	]*):\s*/m;

	# yyy an approach once considered but not used
	# $num = $.;	# linenum
	# s/^/ $num++ . ":" /e	while (/\n/g);
	# /\G  ($N\#.*\n)+  (?=$N[^\#]) /gx	# comment block
	# /\G  ($N\S.*\n)+  (?=$N[^\S]) /gx	# element on one or more lines
	# /\G  (#.*\n)+(?=[^#])/g
	# /^#.*?\n[^#]/s        # (?=lookahead)
	#return "_=$_\n" . join(", ", @$r_elems);	# to check results

	return $msg;
}

# ANVL value split
# xxx rename to anvl_valarray?
# returns empty string on success or string beginning "warning:..."
# r_svals is reference to an array that will be filled upon return
sub anvl_valsplit { my( $value, $r_svals )=@_;

	! defined($value) and
		return "needs an ANVL value";
	ref($r_svals) ne "ARRAY" and
		return "2nd arg must reference an array";
	local $_;

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
# XXXXXXX need way to encode newlines (using '\n' in interim)

our %anvl_encoding;

#%cn :
#%sc ;

# xxxxx handle these separately
#	# XXXX remove %% from erc/anvlspec?
#	'%'   =>  '%pe',	# decodes to % (0x25)  xxxx do this first?
#	'_'   =>  '',		# a non-character used as a syntax shim
#	'{'   =>  '',		# a non-character that begins an expansion block
#	'}'   =>  '',		# a non-character that ends an expansion block

# Takes a single arg.
sub anvl_decode {

	local $_ = shift(@_) || '';

	pos() = 0;			# reset \G for $_ just to be safe
	while (/(?=\%{)/g) {		# lookahead; \G matches just before
		my $p = pos();		# note \G position before it changes
		s/\G \%{ (.*?) \%}//xs	# 's' modifier makes . match \n
			or last;	# if no closing brace, skip match
		my $exp_block = $1;	# save removed expansion block
		$exp_block =~ s/\s+//g;	# strip it of all whitespace
		pos() = $p;		# revert \G to where we started and
		s/\G/$exp_block/;	# re-insert changed expansion block
	}
	s/\%[}{]//g;			# remove any remaining unmatched
	s/\%_//g;			# xxx %_ -> ''
	s/\%\%/\%pe/g;			# xxx ??? xxxx???
	# decode %XY where XY together don't form a valid pair of hex digits
	s/\%([g-z][a-z]|[a-z][g-z])/$anvl_decoding{$1}/g;
	return $_;
}

# xxx encoding should be context-sensitive, eg, name, value
sub anvl_encode { my( $s )=@_;
	
	# XXXX just define this in the module??
	unless (%anvl_encoding) {	# one-time definition
		# This just defines an inverse mapping so we can encode.
		$anvl_encoding{$anvl_decoding{$_}} = $_
			for (keys %anvl_decoding);
	}
	$s =~
	  s/([ !\"#\$\%&'\(\)\*\+,\/:;<=>\?@\[\\\]\|\0])/\%$anvl_encoding{$1}/g;
	return $s;
}

# return $name in natural word order, using ANVL inversion points
# repeat for each final comma present
sub anvl_name_naturalize { my( $name )=@_;

	$name ||= '';
	$name =~ /^\s*$/	and return $name;	# empty

	# "McCartney, Paul, Sir,,"
	# a, b, c, d, e,,, -> e d c a, b
	my $prefix = '';
	while ($name =~ s/,\s*$//) {
		$name =~ s/^(.*),\s*([^,]+)(,*$)/$1$3/ and
			$prefix .= $2 . ' ';
	}
	return $prefix . $name;
}

sub anvl_summarize { my( @nodes )=@_; }

# XXXXX doesn't this really belong in an ERC.pm module?
#
# ordered list of kernel element names
our @kernel_labels = qw(
	who
	what
	when
	where
	how
	why
	huh
);
#
# This routine inspects and possibly modifies in place the kind of element
# array resulting from a call to anvl_recarray(), which splits and ANVL
# record.  It is useful for transforming short form ERC elements into full
# form elements, for example, to expand "erc:a|b|c|d" into the equivalent,
# "erc:\nwho:a\nwhat:b\nwhen:c\nwhere:d".
# It returns the empty string on success, otherwise an error message.
#
sub erc_anvl_expand_array { my( $r_elems )=@_;

	use File::ANVL;
	my ($lineno, $name, $value, $msg, @svals, $sval);
	my $me = 'erc_anvl_expand_array';
	my $i = 3;		# skip first 3 elems (anvl array preamble)
 	while (1) {
		$lineno = $$r_elems[$i++];
		$name = $$r_elems[$i++] || '';
		$value = $$r_elems[$i++] || '';
		last	unless defined $lineno;	# end of record
 		next			# skip unless we have erc-type thing
			if ($name ne 'erc' || $value =~ /^\s*$/);
			#if ($name !~ /^erc\b/ || $value =~ /^\s*$/);
			# xxx should do this for full generality

		# If here, we have an erc-type thing with a non-empty value.
		#
		($msg = anvl_valsplit($value, \@svals)) and
			return "error: $me: anvl_valsplit: $msg";
	 
		# XXXX only doing straight "erc" (eg, not erc-about)
		my $j = 0;
		my @extras = ();
		# If we exceed known labels, we'll re-use last known label.
		my $unknown = $kernel_labels[$#kernel_labels];
		foreach $sval (@svals) {

			# xxx not (yet) tranferring subvalue structure
			#     to anvl_om or other conversion
			# Recall that each $sval is itself a reference to
			# an array of subvalues (often just one element).
			#
			push @extras,		# trust kernel_labels order
				$lineno,
				$kernel_labels[$j++] || $unknown,
				join('; ',	# trim ends of subvalues
					map(m/^\s*(.*?)\s*$/, @$sval)
				);
		}
		# Finally, replace our $value element with '' and append
		# the new extra values we've just expanded.
		splice @$r_elems, $i-1, 1,
			'',		# replaces $value we just used up
			@extras;	# adds new elements from $value
 	}
	return '';			# success
}

# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=============
# xxx checkm _in_  <repo> obj1 obj2 ...  --> returns noids
# xxx checkm _out_ <repo> id1 id2 ...  --> returns objects

# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=============
# xxx do metadata scan of object before ingest and confirm with user that
# the object is correctly identified.  This could even be done remotely.
# Start with informal staff service for depositing objects, returning a
# short url to a stable object, and not clogging up allstaff inboxes with
# huge attachments.  Also applies to any number of draft docs for review
# but in temporary storage (but stable).

# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=============
# xxx do id generator service with 'expiring' ids.  To mint, you tell us
# who you are first.  To get a perm. id, you agree to use your minted id
# and bind it within N months.  We track, and warn you several times
# until N months as elapsed and then reclaim/recycle the id.

############################################
# Output Multiplexer routines
############################################

#    #$erc = "erc: Smith, J.|The Whole Truth|2004|http://example.com/foo/bar";
#    $errmsg = File::ERC::erc_anvl2erc_turtle ($erc, $rec);
#    $errmsg and
#	print("$errmsg\n")
#    or
#	print("turtle record:\n$rec\n")
#    ;

# xxx anvl_fmt not consistent with om_anvl!

sub anvl_om {

	my $om = shift;			# output formatting object
	return "anvl_om: 1st arg not an OM object"
		if ref($om) !~ /^File::OM::/;
	my $p = $om->{outhandle};	# whether 'print' status or small

	my $o = shift ||		# output options
		anvl_opt_defaults();
	my $s = '';			# output strings are returned to $s
	my $st = $p ? 1 : '';		# returns (stati or strings) accumulate
	my ($msg, $anvlrec, $lineno, $name, $value, $pat);

	$s = $om->ostream();		# open stream

	# This next line is a fast (if cryptic) way to accumulate $om->method
	# calls.  Used after each method call, it concatenates strings or
	# ANDs up print statuses depending on the outhandle setting.
	#
	$p and ($st &&= $s), 1 or ($st .= $s);	# accumulate method returns

	# Numbers: record, element in record, and start line
	#
	my ($startline, $recnum, $elemnum) = (1, 0, 0);
	my ($wslines, $rrlines);
	my $r_elems = $om->{elemsref};		# abbreviation
	# xxx is that reference kosher?

	while (1) {

		# Get paragraph (ANVL record) and count lines therein.
		#
		$anvlrec = trimlines(getlines(), \$wslines, \$rrlines);
		$startline += $wslines;
		last		unless $anvlrec;

		$recnum++;		# increment record counter

		$msg = anvl_recarray($anvlrec, $r_elems, $startline, $o);
		$msg		and return "anvl_recarray: $msg";

		# NB: apply 'find' here before possible expansion, which
		# means that a pattern like "who:\s*smith" won't work on
		# on a short form ANVL record.
		#
		$$o{find} and ($anvlrec !~ /$$o{find}/m) and
			next;

		# If caller has set $$o{elemsproc} to a code reference,
		# it is called to process the element array just returned
		# from anvl_recarray.  Typically this is used to convert
		# (with erc_anvl_expand_array) short form ERCs to long
		# form ERCs.  As an optimization, the code is not called
		# if $$o{elemsprocpat} (typically, "erc") is set and
		# doesn't match the raw record string.
		#
		if (ref($$o{elemsproc}) eq "CODE" and	# if code and either
			(! ($pat = $$o{elemsprocpat}))	# no pattern or
				|| $anvlrec =~ $pat) {	# the pattern matches

			($msg = &{$$o{elemsproc}}($r_elems)) and
				return "File::ANVL::elemsproc: $msg";
		}
		ref($om) eq 'File::OM::Turtle' and
			turtle_set_subject($om, $anvlrec);

		# The orec method is given first crack at a new record.
		# It sets and/or clears a number of values for keys (eg,
		# for turtle, $$o{subject}).  $recnum is useful for
		# outputting json separators (eg, no comma if $recnum eq 1)
		# or record numbers in comments (eg, if $$o{verbose}).
		# $startline is useful for parser diagnostics (eg, "error
		# on line 5").
		#
		$s = $om->orec($recnum, $startline, $r_elems);
		$p and ($st &&= $s), 1 or ($st .= $s);

		# Now discard first 3 elements (ANVL record preamble).
		#
		shift(@$r_elems); shift(@$r_elems); shift(@$r_elems);

		$elemnum = 0;	# count of true elements (not comments)
		while (1) {
			$lineno = shift(@$r_elems);
			$name = shift(@$r_elems);
			$value = shift(@$r_elems) || "";

			last	unless defined $name; 	# end of record

			$elemnum++		unless $name eq '#';

			# Skip if 'show' given and not requested.
			$$o{show} and ("$name: $value" !~ /$$o{show}/m) and
				next;

			# Instead of $om->oelem, $om->celem, $om->contelem, 
			# combine open and close into one, but first
			# naturalize values if called upon.
			#
			$$o{invert} and $value =~ /,\s*$/ and
				$value = anvl_name_naturalize($value);
			$s = $om->elem($name, $value, $lineno);

			$p and ($st &&= $s), 1 or ($st .= $s);
		}
		$s = $om->crec($recnum);
		$p and ($st &&= $s), 1 or ($st .= $s);
		$startline += $rrlines;
	}
	$s = $om->cstream();
	$p and ($st &&= $s), 1 or ($st .= $s);

	return $st;
}

# xxx document all om options
# xxx should om also have a recstring slot (for anvlrec)?
# xxx pass in turtle_nosubject (default)?
sub turtle_set_subject {

	my ($om, $anvlrec) = (shift, shift);
	my $r_elems = $om->{elemsref};

	# In order to find the subject element for Turtle/RDF
	# assertions, we need an element name pattern.  If one is
	# defined in $om->{turtle_subjelpat}, use it.  If it's undefined,
	# per-record code will use 'where' if it thinks the record
	# is an ERC, or use 'identifier|subject' as a last resort.
	# If no element matching subjelpat is found, $om->{subject}
	# will default to $om->{turtle_nosubject}.
	#
	my $subjpat = $om->{turtle_subjelpat} ||
		($anvlrec =~ /^erc\s*:/m
			? "^where\$" :	# 1st where in an 'erc', or
		($anvlrec =~ /^(identifier|subject)\s*:/m
			? "^$1\$" :	# 1st identifier or subject,
		($anvlrec =~ /^(.+)\s*:\s*(\n\s+)*\w/
			? "^$1\$" :	# or 1st non-empty element
		'')));			# or nothing (always matches)

	# Now find a 'subject' for our Turtle/RDF assertions.
	#
	my $j = 1;	# element names in positions 1, 4, 7, ...
	1 while ($j < $#$r_elems and			# quickly find it
		@$r_elems[$j] !~ $subjpat and ($j += 3));
	$om->{subject} = $j < $#$r_elems && $subjpat ?	# if found,
			@$r_elems[$j + 1] :		# use associated value
			$om->{turtle_nosubject};	# else use default
	return $om->{subject};
}

1;

__END__

=head1 NAME

File::ANVL - A Name Value Language routines

=head1 SYNOPSIS

 use File::ANVL;       # to import routines into a Perl script

 getlines(             # read from $filehandle (defaults to *ARGV) up to
         $filehandle   # blank line; returns record read or undef on EOF;
         );            # record may be all whitespace (almost EOF)

 trimlines(            # strip initial whitespace from record, often just
         $record,      # returned by getlines(), and return remainder;
	 $r_wslines,   # optional ref to line count in trimmed whitespace
	 $r_rrlines ); # optional ref to line count of real record lines

 anvl_recarray(        # split $record into array of lineno-name-value
         $record,      # triples, first triple being <anvl, beta, "">
         $r_elems,     # reference to returned array
         $lineno,     # starting line number (default 1)
         $opts );      # options/default, eg, comments/0, autoindent/1

 erc_anvl_expand_array(# change short ERC ANVL array to long form ERC
         $r_elems );   # reference to array to modify in place

 anvl_valsplit(        # split ANVL value into an array of subvalues
         $value,       # input value; arg 2 is reference to returned
         $r_svals );   # array of arrays of returned values

 anvl_rechash(         # split ANVL record into hash of elements
         $record,      # input record; arg 2 is reference to returned
         $r_hash,      # hash; a value is scalar, or array of scalars
         $strict );    # if more than one element shares its name

 anvl_decode( $str );     # decode ANVL-style %xy chars in string

 anvl_name_naturalize(   # convert name from sort-friendly to natural
         $name );        # word order using ANVL inversion points

 anvl_om(                # read and process records from *ARGV
         $om,            # a File::OM formatting object
   {                     # a hash reference to various options
   autoindent => 0,      # don't (default do) correct sloppy indention
   comments => 1,        # do (default don't) preserve input comments
   verbose => 1,         # output record and line numbers (default don't)
   ... } );              # other options listed later

 anvl_opt_defaults();    # return hash reference with factory defaults

 *DEPRECATED*
 anvl_recsplit(         # split record into array of name-value pairs;
         $record,       # input record; arg 2 is reference to returned
         $r_elems,      # array; optional arg 3 (default 0) requires
         $strict );     # properly indented continuation lines
 anvl_encode( $str );   # ANVL-encode string

 *REPLACED*
 # instead of anvl_fmt use File::OM::ANVL object's 'elems' method
 $elem = anvl_fmt(     # format ANVL element, wrapping to 72 columns
         $name,        # $name is what goes to left of colon (:)
         $value,       # $value is what goes to right of colon
	 ... );        # more name/value pairs may follow

=head1 DESCRIPTION

This is documentation for the B<ANVL> Perl module, which provides a
general framework for data represented in the ANVL format.  ANVL (A Name
Value Language) represents elements in a label-colon-value format similar
to email headers.  Specific conversions, based on an "output multiplexer"
L<File::OM>, are possible to XML, Turtle, JSON, and Plain unlabeled text.

The B<OM> package can also be used to build records from scratch in ANVL
or other the formats.  Below is an example of how to create a particular
kind of ANVL record known as an ERC (which uses Dublin Kernel metadata).
For the formats ANVL, Plain, and XML, the returned text string by default
is wrapped to 72 columns.

     use File::OM;
     my $om = File::OM->new("ANVL");
     $anvl_record = $om->elems(
         "erc", "",
         "who", $creator,
         "what", $title,
         "when", $date,
         "where", $identifier)
         . "\n";    # 2nd newline in a row terminates ANVL record

The C<getlines()> function reads from $filehandle up to a blank line and
returns the lines read.  This is a general function for reading
"paragraphs", which is useful for reading ANVL records.  If unspecified,
$filehandle defaults to *ARGV, which makes it easy to take input from
successive file arguments specified on the command line (or from STDIN if
none) of the calling program.

For convenience, C<trimlines()> is often used to process the record just
returned by C<getlines()>.  It strips leading whitespace, optionally
counts lines, and returns undef if the passed record is undefined or
contains only whitespace, both being equivalent to end-of-file (EOF).

These functions treat whitespace specially.  Input is read up until at
least one non-whitespace character and a blank line (two newlines in a
row) or EOF is reached.  If EOF is reached and the record would contain
only whitespace, undef is returned.  Input line counts for preliminary
trimmed whitespace ($wslines) and real record lines ($rrlines) can be
returned through optional scalar references given to C<trimlines()>.
These functions work together to permit the caller access to all inputs,
to accurate line counts, and a familiar "loop until EOF" paradigm, as in

     while (defined trimlines(getlines(), \$wslcount, \$rrlcount)) ...

The C<anvl_recarray()> function splits an ANVL record into elements,
returning them via the array reference given as the second argument. Each
returned element is a triple consisting of line number, name, and value.
An optional third argument gives the starting line number (default 1).
An optional fourth argument is a reference to a hash containing options;
the argument { comments => 1, autoindent => 0 } will cause comments to be
kept (stripped by default) and recoverable indention errors to be flagged
as errors (corrected to continuation lines by default).  This function
returns the empty string on success, or a message beginning "warning:
..." or "error: ...".

The first triple of the returned array is special in that it describes
the origin of the record; its elements are

     INDEX   NAME        VALUE
       0     format      original format ("ANVL", "JSON", "XML", etc)
       1     <unused>
       2     <unused>

The remaining triples are free form except that the values will have been
drawn from the original format and possibly decoded.  The first item
("lineno") in each remaining triple is a number followed by a letter,
such as "34:" or "6#".  The number indicates the line number (or octet
offset, depending on the origin format) of the start of the element.  The
letter is either ':' to indicate a real element or '#' to indicate a
comment; if the latter, the element name has no defined meaning and the
comment is contatined in the value.  Here's example code that reads a
3-element record and reformats it.

     ($msg = File::ANVL::anvl_recarray('
     a: b c
     d:  e
       f
     g:
       h i
     '     and die "anvl_recarray: $msg";  # report what went wrong
     for ($i = 4; $i < $#elems; $i += 3)
         { print "[$elems[$i] <- $elems[$i+1]]  "; }

which prints

     [a <- b c]  [d <- e f]  [g <- h i]

C<erc_anvl_expand_array()> inspects and possibly modifies in place the
kind of element array resulting from a call to C<anvl_recarray()>.  It
returns the empty string on success, otherwise an error message.  This
routine is useful for transforming a short form ERC ANVL record into long
form, for example, expanding C<erc: a | b | c | d> into the equivalent,

     erc:
     who: a
     what: b
     when: c
     where: d

The C<anvl_valsplit()> function splits an ANVL value into sub-values 
(svals) and repeated values (rvals), returning them as an array of arrays
via the array reference given as the second argument.  The top-level of
the array represents svals and the next level represents rvals.  This
function returns the empty string on success, or a message beginning
"warning: ..." or "error: ...".

The C<anvl_rechash()> function splits an ANVL record into elements,
returning them via the hash reference given as the second argument.  A
hash key is defined for each element name found.  Under that key is
stored the corresponding element value, or an array of values if more
than one occurrence of the element name was encountered.  This function
returns the empty string on success, or a message beginning "warning: ..."
or "error: ...".

The C<anvl_decode()> function takes an ANVL-encoded string and returns it
after converting encoded characters to the standard representaion (e.g.,
%vb becomes `|').  Some decoding, such as for the expansion block below,

     print anvl_decode('http://example.org/node%{
                 ? db = foo
                 & start = 1
                 & end = 5
                 & buf = 2
                 & query = foo + bar + zaf
            %}');

will affect an entire region.  This code prints

  http://example.org/node?db=foo&start=1&end=5&buf=2&query=foo+bar+zaf

The C<anvl_name_naturalize()> function takes an ANVL string (aval)
and returns it after inversion at any designated inversion points.
The input string will be returned if it does not end in a comma (`,').
The more terminal commas, the more inversion points tried.  For example,
the calls

     anvl_name_naturalize("Smith, Pat,");
     anvl_name_naturalize("McCartney, Paul, Sir,,")
     anvl_name_naturalize("Hu Jintao,")

take sort-friendly strings (commonly used to make ANVL records easy
to sort) and return the natural word order strings,

     Pat Smith
     Sir Paul McCartney
     Hu Jintao

The C<anvl_om()> routine takes a formatting object created by a call to
C<File::OM($format)>, reads a stream of ANVL records, processes each
element, and calls format-specific methods to build the output.  Those
methods are typically affected by transferring command line options in at
object creation time.

     use File::ANVL;
     use File::OM;
     my $fmt = $opt{format};       
     $om = File::OM->new($opt{format},      # from command line
         {comments => $opt{comments}) or    # from command line
             die "unknown format $fmt";

Options control various aspects of reading ANVL input records.  The
'autoindent' option (default on) causes the parser to recover if it can
when continuation lines are not properly indented.  The 'comments'
options (default off) causes input comments to be preserved in the
output, format permitting.  The 'verbose' option inserts record and line
numbers in comments.  Pseudo-comments will be created for formats that
don't natively define comments (JSON, Plain).

Like the individual OM methods, C<anvl_om()> returns the built string by
default, or the return status of C<print> using the file handle supplied
as the 'outhandle' options (normally set to '') at object creation time,
for example,

     { outhandle => *STDOUT }

The way C<anvl_om()> works is roughly as follows.

     $om->ostream();                                    # open stream
     ... { # loop over all records, eg, $recnum++
     $anvlrec = trimlines(getlines());
     last         unless $anvlrec;
     $err = anvl_recarray($anvlrec, $$o{elemsref}, $startline, $opts);
     $err         and return "anvl_recarray: $err";
     ...
     $om->orec($anvlrec, $recnum, $startline);          # open record
     ...... { # loop over all elements, eg, $elemnum++
     $om->elem($name, $value, $elemnum, $lineno);       # do element
     ...... }
     $om->crec($recnum);                                # close record
     ... }
     $om->cstream();                                    # close stream


DEPRECATED: The C<anvl_recsplit()> function splits an ANVL record into
elements, returning them via the array reference given as the second
argument.  Each returned element is a pair of elements: a name and a
value.  An optional third argument, if true (default 0), rejects
unindented continuation lines, a common formatting mistake.  This
function returns the empty string on success, or message beginning
"warning: ..." or "error: ...".  Here's an example that extracts and uses
the first returned element.

     ($msg = anvl_recsplit($record, $elemsref)
         and die "anvl_recsplit: $msg";  # report what went wrong
     print scalar($$elemsref), " elements found\n",
         "First element label is $$elemsref[0]\n",
         "First element value is $$elemsref[1]\n";

=head1 SEE ALSO

A Name Value Language (ANVL)
	L<http://www.cdlib.org/inside/diglib/ark/anvlspec.pdf>

A Metadata Kernel for Electronic Permanence (PDF)
	L<http://journals.tdl.org/jodi/article/view/43>

=head1 HISTORY

This is a beta version of ANVL tools.  It is written in Perl.

=head1 AUTHOR

John A. Kunze I<jak at ucop dot edu>

=head1 COPYRIGHT AND LICENSE

Copyright 2009-2010 UC Regents.  Open source BSD license.

=head1 PREREQUISITES

Perl Modules: L<File::OM>

Script Categories:

=pod SCRIPT CATEGORIES

UNIX : System_administration

=cut

