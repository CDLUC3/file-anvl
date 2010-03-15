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
$VERSION = sprintf "%d.%02d", q$Name: Release-0-11 $ =~ /Release-(\d+)-(\d+)/;
our @EXPORT = qw(
	anvl_fmt anvl_split get_namaste set_namaste file_value elide
	num2dk
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

# if length is 0, go for it.
#
my $ridiculous = 4294967296;	# max length is 2^32  XXX better way?

sub file_value { my( $file, $value, $how, $length )=@_;

	my $ret_value = \$_[1];
	use constant OK => "";		# empty string on return means success

	! defined($file) and
		return "needs a file name";

	# make caller be explicit about whether doing read/write/append
	#
	$file !~ /^\s*(<|>|>>)\s*(\S.*)/ and
		return "file ($file) must begin with '<', '>', or '>>'";
	my ($mode, $statfname) = ($1, $2);

	# we're to do value-to-file
	# in this case we ignore $how and $length
	# XXX should we not support a trim??
	if ($mode =~ />>?/) {
		! defined($value) and
			return "needs a value to put in '$file'";
		! open(OUT, $file) and
			return "$statfname: $!";
		my $r = print OUT $value;
		close(OUT);
		return ($r ? OK : "write failed: $!");
	}
	# If we get here, we're to do file-to-value.

	my $go_for_it = (defined($length) && $length eq "0" ? 1 : 0);
	my $statlength = undef;

	if (defined($length)) {
		$length !~ /^\d+$/ and
			return "length unspecified or not an integer";
	}
	elsif ($statfname ne "-") {
		# no length means read whole file, but be reasonable
		$statlength = (-s $statfname);
		! defined($statlength) and
			return "$statfname: $!";
		$length = ($statlength > $ridiculous
			? $ridiculous : $statlength);
	}
	else {
		$length = $ridiculous;
	}

	$how ||= "trim";		# trim (def), raw, untaint
	$how = lc($how);
	$how ne "trim" && $how ne "raw" && $how ne "untaint" and
		return "third arg ($how) must be one of: trim, raw, or untaint";

	! open(IN, $file) and
		return "$statfname: $!";
	if ($go_for_it) {		# don't be reasonable about length
		local $/;
		$$ret_value = <IN>;
		close(IN);
	}
	else {
		my $n = read(IN, $$ret_value, $length);
		close(IN);
		! defined($n) and
			return "$statfname: failed to read $length bytes: $!";
		# XXXX do we have to read in a loop until all bytes come in?
		return "$statfname: read fewer bytes than expected"
			if (defined($statlength) && $n < $statlength);
	}

	if ($how eq "trim") {
		$$ret_value =~ s/^\s+//;
		$$ret_value =~ s/\s+$//;
	}
	elsif ($how eq "untaint") {
		if ($$ret_value =~ /([-\@\w.]+)/) {
			$$ret_value = $1;
		}
	}
	# elsif ($how eq "raw") { then no further processing }

	return OK;
}

# xxx unicode friendly??
#
# XXXX test with \n in string???
my $max_default = 16;		# is there some sense to this? xxx use
				# xxx fraction of display width maybe?

sub elide { my( $s, $max, $ellipsis )=@_;

	return undef
		if (! defined($s));
	$max ||= $max_default;
	return undef
		if ($max !~ /^(\d+)([esmESM]*)([+-]\d+%?)?$/);
	my ($maxlen, $where, $tweak) = ($1, $2, $3);

	$where ||= "e";
	$where = lc($where);

	$ellipsis ||= ($where eq "m" ? "..." : "..");
	my $elen = length($ellipsis);

	my ($side, $offset, $percent);		# xxx only used for "m"?
	if (defined($tweak)) {
		($side, $offset, $percent) = ($tweak =~ /^([+-])(\d+)(%?)$/);
	}
	$side ||= ""; $offset ||= 0; $percent ||= "";
	# XXXXX finish this! print "side=$side, n=$offset, p=$percent\n";

	my $slen = length($s);
	return $s
		if ($slen <= $maxlen);	# doesn't need elision

	my $re;		# we will create a regex to edit the string
	# length of orig string after that will be left after edit
	my $left = $maxlen - $elen;

	my $retval = $s;
	# Example: if $left is 5, then
	#   if "e" then s/^(.....).*$/$1$ellipsis/
	#   if "s" then s/^.*(.....)$/$ellipsis$1/
	#   if "m" then s/^.*(...).*(..)$/$1$ellipsis$2/
	if ($where eq "m") {
		# if middle, we split the string
		my $half = int($left / 2);
		$half += 1	# bias larger half to front if $left is odd
			if ($half > $left - $half);	# xxx test
		$re = "^(" . ("." x $half) . ").*("
			. ("." x ($left - $half)) . ")\$";
			# $left - $half might be zero, but this still works
		$retval =~ s/$re/$1$ellipsis$2/;
	}
	else {
		my $dots = "." x $left;
		$re = ($where eq "e" ? "^($dots).*\$" : "^.*($dots)\$");
		if ($where eq "e") {
			$retval =~ s/$re/$1$ellipsis/;
		}
		else {			# else "s"
			$retval =~ s/$re/$ellipsis$1/;
		}
	}
	return $retval;
}

# xxx is this routine internal only?
# only first arg required
# return tvalue given fvalue
sub namaste_tvalue { my( $fvalue, $max, $ellipsis )=@_;

	my $tvalue = $fvalue;
	$tvalue =~ s,/,\\,g;
	$tvalue =~ s,\n+, ,g;
	$tvalue =~ s,\p{IsC},?,g;
	# XXX if (windows) s/badwinchars/goodwinchars/
	# XXX eg, $s =~ tr[<>:"/?*][.]
	# XXX not yet doing unicode or i18n

	my $xx = elide($tvalue, $max, $ellipsis);
	return $xx;
	#return elide($tvalue, $max, $ellipsis);
}

# first two args required
# returns empty string on success, otherwise a diagnostic
sub set_namaste { my( $num, $fvalue, $max, $ellipsis )=@_;

	return 0
		if (! defined($num) || ! defined($fvalue));

	my $fname = "$num=" . namaste_tvalue($fvalue, $max, $ellipsis);

	return file_value(">$fname", $fvalue);
}

use File::Glob ':glob';		# standard use of module, which we need
				# as vanilla glob won't match whitespace

# args give numbers to fetch; no args means return all
# args can be file globs
# returns array of number/fname/value triples (every third elem is number)
sub get_namaste {

	my (@in, @out);
	if ($#_ < 0) {			# if no args, get all files that
		@in = bsd_glob('[0-9]=*');	# start "<digit>=..."
	}
	else {				# else do globs for each arg
		push @in, bsd_glob($_ . '=*')
			while (defined($_ = shift @_));
	}
	my ($number, $fname, $fvalue, $status);
	while (defined($fname = shift(@in))) {
		# XXX other params for file_value??
		$status = file_value("<$fname", $fvalue);
		($number) = ($fname =~ /^(\d*)=/);
		$number = ""
			if (! defined($number));
		push @out, $number, $fname, ($status ? $status : $fvalue);
	}
	return @out;
}

sub num2dk{ my( $number )=@_;

	return $kernel{$number}
		if (exists($kernel{$number})
			&& defined($kernel{$number}));
	return $number;
}

__END__

=head1 NAME

ANVL - routines to support A Name Value Language, version 0.1

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

 $stat = set_namaste( $number, $fvalue, $max, $ellipsis )
                            # Return empty string on success, else an
                            # error message.  The first two arguments are
                            # required; remaining args passed to elide().
                            # Uses the current directory.

 # Example: set the directory type and title tag files.
 ($msg = set_namaste(0, "dflat_0.4")
          || set_namaste(2, "Crime and Punishment"))
     and die("set_namaste: $msg\n");

 @num_nam_val_triples = get_namaste( $filenameglob, ...)
                            # Return an array of number/filename/value
                            # triples (eg, every 3rd elem is number).
			    # Args give numbers (as file globs) to fetch
			    # (eg, "0" or "[1-4]") and no args is same
			    # as "[0-9]".  Uses the current directory.

 # Example: fetch all namaste tags and print.
 my @nnv = get_namaste();
 while (defined($num = shift(@nnv))) {  # first of triple is tag number;
     $fname = shift(@nnv);              # second is filename derived...
     $fvalue = shift(@nnv);             # from third (the full value)
     print "Tag $num (from $fname): $fvalue\n";
 }

 $stat = file_value(   # Move file contents to or from a string value.
            $file,          # precede with <|>|>> to read|write|append
            $value,         # returns value read
            $how,           # (opt) one of trim(default)|raw|untaint
            $maxlen);       # (opt) move not more than $maxlen chars

 ($msg = file_value(">pid_file", $pid))  # Example: store a file value
         and die("pid_file: $msg\n");
  ...
 ($msg = file_value("<pid_file", $pid))  # Example: read a file value
         and die("pid_file: $msg\n");

 $s = elide(          # Return shorter string, ellipsis marking deletion.
            $string,        # string to be shortened
            $max,           # (opt) max length (default 16) of result,
                            # optionally followed by
                            #   "e" end of string (default)
                            #   "s" start of string
                            #   "m" middle of string
            $ellipsis);     # (opt) string to mark deletion, defaults
                            # to ".." for "e" or "s" deletion and
                            # defaults to "..." for "m" deletion

 print elide($title, "${displaywidth}m")      # Example: fit long title
        if (length($title) > $displaywidth);  # by eliding from middle

=head1 DESCRIPTION

This is very brief documentation for the B<ANVL> Perl module, which deals
with routines for representing data or metadata values in two very simple
forms.  ANVL (A Name Value Language) is label-colon-value format similar
to email headers.  This module also implements the Namaste (Name as Text)
convention for containing a data element completely within the content of
a file, using as filename an approximation of the value preceded by a
numeric tag.

The C<anvl_fmt()> function returns a plain text string (in
label-colon-value format) representing an anvl element.  Its main purpose
is to URL-encode (%-encode) the label and wrap lines for convenient
printing and screen viewing.  Newlines in the value are preserved.

The functions C<file_value()> and C<elide()> are general purpose and do
not rely on ANVL or Namaste; however, they are used by C<set_namaste()>
and C<get_namaste()>.

=head1 SEE ALSO

A Name Value Language (ANVL)
	L<http://www.cdlib.org/inside/diglib/ark/anvlspec.pdf>

Directory Description with Namaste Tags
	L<http://www.cdlib.org/inside/diglib/namaste/namastespec.html>

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

