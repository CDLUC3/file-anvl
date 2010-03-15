package ERC;

require Exporter;	# use Exporter ();
use vars qw(@ISA @EXPORT @EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(
	erc_elem erc_start erc_support erc_set_start erc_valencode
	erc_debug
	date2temper test_temper
);

# ERC (Electronic Resource Citation) formatting routines (Perl module)
#   Alpha version -- for demonstration only.
#
# Store as 'ERC.pm' and type 'perldoc ERC' for documentation.
#
# Author:  John A. Kunze, jak@ucop.edu, California Digital Library
# 
# ---------
# Copyright (c) 2003 UC Regents
# 
# Permission to use, copy, modify, distribute, and sell this software and
# its documentation for any purpose is hereby granted without fee, provided
# that (i) the above copyright notices and this permission notice appear in
# all copies of the software and related documentation, and (ii) the names
# of the UC Regents and the University of California are not used in any
# advertising or publicity relating to the software without the specific,
# prior written permission of the University of California.
# 
# THE SOFTWARE IS PROVIDED "AS-IS" AND WITHOUT WARRANTY OF ANY KIND, 
# EXPRESS, IMPLIED OR OTHERWISE, INCLUDING WITHOUT LIMITATION, ANY 
# WARRANTY OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.  
# 
# IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE FOR ANY
# SPECIAL, INCIDENTAL, INDIRECT OR CONSEQUENTIAL DAMAGES OF ANY KIND,
# OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
# WHETHER OR NOT ADVISED OF THE POSSIBILITY OF DAMAGE, AND ON ANY
# THEORY OF LIABILITY, ARISING OUT OF OR IN CONNECTION WITH THE USE
# OR PERFORMANCE OF THIS SOFTWARE.
# ---------

my $debug = 0;			# default is off; to set use erc_debug(1)

# first four args required, the rest optional
sub erc_start { my( $creator, $title, $date, $identifier,
					$description, $because )=@_;

	return "erc:\n" .
		erc_elem("who:   $creator") .
		erc_elem("what:  $title") .
		erc_elem("when:  $date") .
		erc_elem("where: $identifier") .
		# xxx ? rule that how label must be present if there's a why? 
		erc_elem(! defined($description) ?
			(defined($because) ? "how:   (:unav) Unavailable" : "")
			: "how:    $description") .
		erc_elem(! defined($because) ? "" : "why:   $because")
	;
}

sub erc_support { my( $who, $what, $when, $where )=@_;

	return "erc-support:\n" .
		erc_elem("who:   $who") .
		erc_elem("what:  $what") .
		erc_elem("when:  $when") .
		erc_elem("where: $where")
	;
}
sub erc_set_start { my( $who, $what, $when, $where,
				$howmany, $starting, $total )=@_;

	# xxx these should be wrapped in erc_elem() calls
	return
		"THUMP-Status: 0.1 200 OK\n" .
		"\n" .
		"|set:  $who | $what | $when\n" .
		"	 | $where\n" .
		"here:  $howmany | $starting | $total\n" .
		"\n"
	;
}

# W3C-NOTE: YYYY-MM-DDThh:mm:ss.sTZD, where TZD = Z or +hh:mm or -hh:mm
sub date2temper { my( $s_orig )=@_;

	my $s = lc($s_orig);
	$s =~ s/\s+//g;			# squeeze all whitespace out
	$s =~ s/;/,/g;			# change semi-colons to commas

	# Quick, crude heuristic check for common language constructs.
	#
	$s =~ /nodate/ || $s =~ /dateunknown/ || $s =~ /unknowndate/
			|| $s =~ /n\.d\./
		and return "(:unkn) unknown";

	# Clean up odd stuff, like final a period.
	$s =~ s/\.$//;

	# Check if squeezed date is already in TEMPER format and return,
	# with appropriate type tag, "[:]" (equivalent to [:td]), in
	# front if so.
	# XXX no timezone support (or definition) in TEMPER yet.
	# XXX limited support for lists or ranges
	# XXX no support for "ca." or "circa"
	# XXX no support for doubt: 1934? or 1926?-1934?
	#
	my $slen = length($s);
	$debug and
		print "# date2temper: s_orig=|$s_orig| s=|$s|\n";
	$s =~ /^\d+$/ and
			$slen == 4 ||		# a year only
			$slen == 8 ||		# a particular day
			$slen == 14		# a particular second
		and return "[:] $s"
	;
	# xxx kludge to do quick check for TEMPER year ranges and lists
	$s =~ /^\d\d\d\d([-,]\d\d\d\d)+$/ and
		return "[:] $s";

	# Check a few obvious formats and convert to [:] if possible.
	# For now, look for evidence of the W3C datetime format (the
	# profile of ISO 8601 adopted by Dublin Core).
	#
	# Start by isolating any time zone.
	my $timezone;
	$s =~ s/Z$//i and
		$timezone = "0000" || 1		# force true
	or $s =~ s/([-+]\d\d):(\d\d)// and
		$timezone = $1 . $2
	;
	# Now try to isolate a time of day.
	my ($hours, $mins, $secs, $time);
	if ($s =~ s/T(\d\d):(\d\d)(:\d\d(\.\d+)?)?$//i) {
		$hours = $1;
		$mins = $2;
		$secs = $3;
		$fracsecs = $4;
		defined($secs) and
			$secs =~ s/^://;
		$time = $hours . $mins . (defined($secs) ? $secs : "00");
		defined($timezone) and
			$time .= "/" . $timezone;  # XXX temporarily use "/"
	}
	# By this point, $time is either set or undefined.

	my ($year, $month, $day, $date);
	# Look for month/day/year or month/year format
	if ($s =~ s,^(\d+)/(\d+)(/(\d+))?,,) {
		($month, $day, $year) = ($1, $2, $4);
		! defined($year)
			and $year = $day || 1
			and $day = "00" || 1
		;
		# xxx should check length of $day and $month to see if == 4
		#     which means it was really a year
		length($year) == 2 and
			$year = ($year > 50 ? "20" : "19") . $year;
		length($month) == 1 and
			$month = "0" . $month;
		length($day) == 1 and
			$day = "0" . $day;
		$date = $year . $month . $day;
		length($s) == 0 and		# no remainder (good result)
			return "[:] $date"
		or				# remainder (something's wrong)
			return "$s_orig" .
				($debug ? "remainder |$s|" : "")
		;
	}
	# xxx note: no range checking has been done

	# Look for yyyy-mm-dd format.
	$s =~ s/^(\d\d\d\d)// and
		$year = $1;
	$s =~ s/^-(\d\d)// and
		$month = $1 || 1	# force true
	or $s =~ s/^-(\d)// and		# catch non-standard 1-digit month
		$month = "0" . $1
	;
	$s =~ s/^-(\d\d)// and
		$day = $1 || 1		# force true
	or $s =~ s/^-(\d)// and		# catch non-standard 1-digit day
		$day = "0" . $1 || 1
	or
		$day = "00" || 1
	;
	# xxx note: no range checking has been done

	# By this point, if $year is undefined, we don't know this format.
	! defined($year) and
		return $s_orig;
	# If by this point we have anything left in $s, there's a good
	# chance we're off course.

	# Now rebuild $date from scratch.
	$date = $year;
	defined($month) and		# requires $day to be defined
		$date .= $month . $day;
	defined($time) and
		$date .= $time;
	length($s) == 0 and			# no remainder (good result)
		return "[:] $date"
	or					# remainder (partial result)
		return $s_orig
		#return "s=$date (remainder '$s' grokking $s_orig)"
	;
}

# XXX belongs in separate test script
sub test_temper {
	my @before_after = (
		'2003-04-12T16:58:01.345Z',	'20030412165801.345/0000',
		'2003-04-12T16:58:01',		'20030412165801',
		'2003-04-12T16:58Z',		'20030412165800/0000',
		'2003-04-12',			'20030412',
		'2003-1-9',			'20030109',
		'2003-04-12T00:00-01:00',	'20030412000000/-0100',
		' 1999 12 13  ',		'19991213',
		'1/4/45',			'19450104',
	);
	my ($before, $after, $expected);

	while (@before_after) {
		$before = shift @before_after;
		$expected = shift @before_after;
		#print date2temper($before), "\n";
		$after = date2temper($before);
		$after =~ s/\[:\] //;
		$after ne $expected and
			print "test failed, $before:\n\twanted\t|$expected|",
						      "\n\tgot\t|$after|\n";
	}
}

sub erc_debug { my( $n )=@_;
	$debug = $n;
	return 1;
}

sub erc_valencode { my( $valarrayref )=@_;

	my ($retval, $v) = ("", "");
	for $v ( @{$valarrayref} ) {
		$v = entity_to_txt($v);
		$v =~ s/\|/%!/g;	# encode any pre-existing separators
		$retval .= "$v | ";
	}
	$retval = substr($retval, 0, -3);	# remove last separator
	return $retval;
}

use Text::Wrap;
my $maxcols = 72;
$Text::Wrap::columns = $maxcols;
$Text::Wrap::huge = 'overflow';		# don't break long values

# Make an ERC element.
#
# XXX needed any more?
my $except_re = qr/([\001-\037\177-\377])/;

sub erc_elem { my( $s )=@_;

	$s eq "" and		# return an empty string untouched (add no \n)
		return $s;
	$s =~ s/\n//g;		# replace every \n with " " -- this case is
				# not expected, but would screw things up
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

use HTML::Entities;
use Encode;

sub entity_to_txt { my( $s )=@_;

	$s !~ /&\S+;/ and
		return $s;
	$s =~ s|&quot;|"|gs;

	return
		encode("UTF8", decode_entities($s));
}

1;

__END__

=head1 NAME

ERC - Electronic Resource Citation tools, version 0.1

=head1 SYNOPSIS

 use ERC;

 $elem = erc_elem("$label: $string");
	# Wraps text to 72 columns, appends newline to end the value.
	# The $label can be "who", "what", "when", "where", etc, or can
	# begin a new erc "story", such as "erc-support:\nPermanent".

 $erc = erc_start($creator, $title, $date, $identifier,
			[ $description, [ $because ] ]);
	# ... which is roughly short-hand for...
 $erc = "erc:\n" .
	erc_elem("who: $creator") .
 	erc_elem("what: $title") .
 	erc_elem("when: $date") .
 	erc_elem("where: $identifier") .
 	erc_elem("how: $description") .		# optional
 	erc_elem("why: $because");		# optional

 $erc .= "\n";		# two "\n" characters in a row terminate an ERC record

 $erc .= erc_support($who, $what, $when, $where);
	# Appends to an ERC an expression of the commitment made to the
	# the object: who made it, what it was, when it was made, and
	# where a fuller explanation of the commitment may be found.

 $set_intro = erc_set_start($who, $what, $when, $where,
				$howmany, $starting, $total);
	# Creates an HTTP header, blank line, special set descriptor record,
	# and another blank line.  This precedes a set of ERC records (e.g.,
	# 1 record, starting at record 1, from a result set of 1 record).

=head1 DESCRIPTION

The erc_elem function returns a plain text string representing an ERC
element after doing some %-encoding of a line of data (in label: value
format), and tries to perform some simple line wrapping for convenient
printing and screen viewing.

The erc_start function returns a text string representing the beginning of
an ERC record.  It is a short-hand way of calling erc_elem with the first
four to six elements of an ERC (values for the first four are required).

There is no "erc_end" function.  Instead, the caller is responsible
(after appending any number of extra elements) for properly terminating
the ERC record, which ends when two "\n" (newline) characters appear in
a row.  Usually, this means appending a single newline since each
element ends with a newline.

The erc_support function returns a string similar in form to erc_start
but telling a different story.  While the first segment of an ERC tells
the story of an expression of the object, this segment (often appended
to the first) tells the story of the support commitment made to it:
who made the commitment, what the nature of the commitment was, when it
was made, and where a fuller explanation of the commitment may be found.

The erc_set_start function returns a text string representing the preamble
that normally introduces a set of one or more ERC records.  The string has
two parts.  First is an HTTP header identifying the type of text stream
that follows and a blank line; this part is meant to terminate a block of
HTTP headers.  Second is a special record (also ending with a blank line)
that describes the particular set ERC records that follows it.

The preamble identifies who created the set, what its title (preferably
human-oriented) is, when it was created, and where an automated process
can access the set.  The last line of the preamble is a three-part element
named "here".  Its parts tell the recipient that here one can expect to
find, respectively, $howmany records, starting at $starting, from a set
of $total records.  For example, 1, 1, and 1 for a one-record set, such
as would be produced by a known-item search.

=head1 REFERENCES

A Metadata Kernel for Electronic Permanence (PDF)
	http://jodi.ecs.soton.ac.uk/Articles/v02/i02/Kunze/

=head1 HISTORY

This is an alpha version of ERC tools.  It is written in Perl.

=head1 BUGS

This API needs more functions, but which?  Comments to jak@ucop.edu.

=head1 AUTHOR

John A. Kunze E<lt>jak@ucop.eduE<gt>.

=cut
