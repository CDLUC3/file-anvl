package File::ERC;

use 5.006;
use strict;
use warnings;

our $VERSION;
$VERSION = sprintf "%d.%02d", q$Name: Release-0-21 $ =~ /Release-(\d+)-(\d+)/;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
);

our @EXPORT_OK = qw(
	num2tag tag2num tag2num_init
);

our %erc_terms = (
	'h10'	=> 'about-erc',	# analog for dir_type?
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
	'h9'	=> 'erc',	# h0->h9 to not collide with dir_type
	'h0'	=> 'dir_type',
	'v1'	=> ':etal',
	'h509'	=> 'format',
	'c2'	=> 'four h\'s',
	'h510'	=> 'identifier',
	'h602'	=> 'in',
	'h5'	=> 'how',
	'h512'	=> 'language',
	'c3'	=> 'metadata',
	'h30'	=> 'meta-erc',	# dirtype?
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
	'h20'	=> 'support-erc',	# dirtype?
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

our %erc_tags;			# for lazy evaluation
our @erc_termlist;		# for lazy evaluation

sub tag2num_init {

	@erc_termlist = sort values %erc_terms;	# so we can grep
	$erc_tags{$erc_terms{$_}} = $_		# so we can inverse map
		for (keys %erc_terms);
}

sub tag2num {

	defined(@erc_termlist) && defined(%erc_tags) or
		tag2num_init();		# one-time lazy definition
	my (@ret, $tag);
	foreach $tag (@_) {
		# if it doesn't look like a regexp, do exact match
		push(@ret, grep(
			($tag =~ /[\\\*\|\[\+\?\{\^\$]/ ? /$tag/ : /^$tag$/),
			@erc_termlist));
	}
	return @ret;
}

# Returns an array of terms corresponding to args given as coded
# synonyms for Dublin Kernel elements, eg, num2tag('h1') -> 'who'.
#
sub num2tag {

	my (@ret, $code);
	for (@_) {
		# Assume an 'h' in front if it starts with a digit.
		#
		($code = $_) =~ s/^(\d)/h$1/;

		# Return a defined hash value or the empty string.
		#
		push @ret, defined($erc_terms{$code}) ?
			$erc_terms{$code} : '';
	}
	return @ret;
}

1;

__END__

=head1 NAME

File::ERC - support for Electronic Resource Citations

=head1 SYNOPSIS

 use File::ERC;           # to import routines into a Perl script

 File::ERC::num2tag(      # return terms (array) corresponding to args
         $num, ... );     # given as coded synonyms for Dublin Kernel
	                  # elements, eg, num2tag('h1') -> 'who'; `h' is
			  # assumed in front of arg that is pure digits

=head1 DESCRIPTION

This is documentation for the B<ERC> Perl module, with support for
metadata labels in an ERC (Electronic Resource Citation) record, which
can be represented in a variety of underlying syntaxes, such as ANVL,
Turtle, XML, and JSON.  The ERC elements include Dublin Core Kernel
metadata.

=head1 SEE ALSO

A Metadata Kernel for Electronic Permanence (PDF)
	L<http://journals.tdl.org/jodi/article/view/43>

=head1 HISTORY

This is an alpha version of an ERC tool.  It is written in Perl.

=head1 AUTHOR

John A. Kunze I<jak at ucop dot edu>

=head1 COPYRIGHT AND LICENSE

Copyright 2009-2010 UC Regents.  Open source BSD license.

=head1 PREREQUISITES

Script Categories:

=pod SCRIPT CATEGORIES

UNIX : System_administration

=cut

#old pod
# erc_anvl_longer(         # given short form ERC in ANVL, return the
#         $erc );          # long, explicitly tagged (canonical) form;
#                          # harmless if $erc already in canonical form
#
# erc_anvl2erc_turtle(     # convert ERC/ANVL to ERC/Turtle, returning
#         $erc,            # empty string on success, message on error
#         $rec             # returned Turtle record
#         $rec_sep         # (opt) separator string on end of URI, eg, #
#         $rec_id );       # (opt) record id for end of URI, eg, #a123

# XXX this up to #====== line is in ANVL.pm as of Feb 11, 2010
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
	my ($linenum, $name, $value, $msg, @svals, $sval);
	my $me = 'erc_anvl_expand_array';
	my $i = 3;		# skip first 3 elems (anvl array preamble)
 	while (1) {
		$linenum = $$r_elems[$i++];
		$name = $$r_elems[$i++];
		$value = $$r_elems[$i++];
		last	unless defined $linenum;	# end of record
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
		# If we exceed known labels, we'll use the last label.
		my $unknown = $kernel_labels[$#kernel_labels];
		foreach $sval (@svals) {

			# xxx not (yet) tranferring subvalue structure
			#     to anvl_om or other conversion
			# Recall that each $sval is itself a reference to
			# an array of subvalues (often just one element).
			#
			push @extras,		# trust kernel_labels order
				$linenum,
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


#===================================

use File::ANVL;

# ordered list of kernel element names
# Preserving this order is critical for processing
# short form ERCs.
#
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
sub erc_anvl2erc_turtle { my( $erc, $rec, $rec_sep, $rec_id )=@_;

	defined($erc)		or return "undefined input";
	if ($erc !~ /^erc.*:/) {
		$erc =~ s/^([^:]*:?).*/$1/s;
		return '"' . $erc . '" does not start an ERC/ANVL record';
	}
	scalar(@_) < 2 || ref($rec) ne "" and
		return "2nd arg should be string to receive converted record";
	my $r_rec = \$_[1];	# create better name for return string
	$rec_sep = ""		unless defined $rec_sep;	# xxx?
	$rec_id = ""		unless defined $rec_id;		# xxx?
	# xxx test $rec_sep = "#"; $rec_id = "a1";

	$erc = erc_anvl_longer($erc)		# canonicalize if needed
		if $erc =~ /^erc.*:\s*(\n\s+)*\S/;

	my ($msg, %rhash);
	($msg = anvl_rechash($erc, \%rhash)) and
		return $msg;

	# start turtle record
	#
	my $this = ($rhash{where} || "");
	$$r_rec =
		"\@prefix erc: <http://purl.org/kernel/elements/1.1/> .\n" .
		"\@prefix : <$this$rec_sep> .\n";

	# Loop through list of kernel terms and print what's there.
	my $first = ":$rec_id ";
	# XXX add meta-who and meta-when  (and meta-what?)
	for (@kernel_labels) {
		defined $rhash{$_} and
			$$r_rec .= ($first ? $first : "      ") . "erc:$_ " .
				'"""' . $rhash{$_} . '"""' . ";\n",
			$first &&= "";		# erase first time through
	}
	$$r_rec .= ".\n";
	return $msg;
}

# @prefix erc: <http://purl.org/kernel/elements/1.1/>.
# @prefix this: <http://www.ccel.org/g/gibbon/decline/>.
# this: erc:who "Gibbon, Edward";
#       erc:what "The Decline and Fall of the Roman Empire";
#       erc:when "1781";
#       erc:where "http://www.ccel.org/g/gibbon/decline/".

#===================================

#my %kernel = (
#	0	=>  'dir_type',
#	1	=>  'who',
#	2	=>  'what',
#	3	=>  'when',
#	4	=>  'where',
#);

##XXX need this any more?
#sub num2dk { my( $number )=@_;
#
#	return $kernel{$number}
#		if (exists($kernel{$number})
#			&& defined($kernel{$number}));
#	return $number;
#}
