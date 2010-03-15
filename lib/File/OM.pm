package File::OM;

use 5.006;
use strict;
use warnings;

our $VERSION;
$VERSION = sprintf "%d.%02d", q$Name: Release-0-20 $ =~ /Release-(\d+)-(\d+)/;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw();

our @EXPORT_OK = qw();

our %EXPORT_TAGS = (all => [ @EXPORT_OK ]);

our %outputformats = (
	anvl	=> 'ANVL',
	json	=> 'JSON',
	plain	=> 'Plain',
	turtle	=> 'Turtle',
	xml	=> 'XML',
);

sub listformats {
	return sort values %outputformats;
}

sub om_opt_defaults { return {

	anvl_mode	=>	# which flavor, eg, ANVL, ANVLR, ANVLS
		'ANVL',		# vanilla (unused for now)
	elemsref	=> [],	# one array to store record elements
	indent		=> '',	# current ident
	indent_start	=> '',	# overall starting indent
	indent_step	=>	# how much to increment/decrement indent
		'  ',		# for XML, JSON
	outhandle	=> '',	# return string by default
	turtle_indent	=>	# turtle has one indent width
		'    ',
	turtle_predns	=>	# turtle predicate namespaces
		'http://purl.org/kernel/elements/1.1/',
	turtle_nosubject =>	# a default subject
		'default',	# XXX not a URI -- what should this be?
	turtle_subjelpat =>	# pattern for matching a subject element
		'',
	turtle_stream_prefix => # symbol we use for turtle
		'erc',
	xml_stream_name	=>	# for XML output, stream tag
		'recs',
	xml_record_name	=>	# for XML output, record tag
		'rec',
	wrap		=> 72,	# at which column to wrap elements (0=nowrap)
	verbose		=> 0,	# more output (default less)
	};
}

sub new {
	my $class = shift;
	my $self = om_opt_defaults();
	my $format = lc shift;
	if ($format) {
		$format = $outputformats{$format};	# canonical name
		$format		or return undef;
		$class = "File::OM::$format";
	}
	else {					# if no format given, expect
		$class =~ /^File::OM::\S/	# to be called from subclass
			or return undef;
	}
	bless $self, $class;

	$class ne 'File::OM::ANVL' && $class ne 'File::OM::Plain'
			&& $class ne 'File::OM::XML'
		and $self->{wrap} = 0;		# turns off wrapping
	my $options = shift;
	my ($key, $value);
	$self->{$key} = $value
		while ($key, $value) = each %$options;

	return $self;
}

sub elems {
	# XXXXX allow $indent_string to be set ??
	# xxxx watch out to make sure label doesn't get wrapped
	# xxx comment encoding needed for long wrapped comments?
	# XXX why do 4 bytes (instead of 2) show up in wget??
	# # %-encode any chars that need it
	# my $except_re = qr/([\001-\037\177-\377])/; XXX needed any more?
	# $s =~ s/$except_re/ "%" . join("", unpack("H2", $1)) /ge;

	my $self = shift;
	my $sequence = '';
	my ($name, $value);
	if ($self->{wrap} <= 0) {		# if we're not wrapping
		while (1) {
			($name, $value) = (shift, shift);	# next arg pair
			last	unless $name or $value;		# done if null
			$sequence .= $self->elem($name, $value);
		}
		return $sequence;
	}

	# ?? fold lines longer than $Text::Wrap::columns chars and wrap
	#  with 1 tab's indention (assume tabwidth=8, line length of 64=72-8
	#  wrap:  initial tab = "", subsequent tab = "\t"
	#  append final newline to end the element

	# If we get here, we're wrapping.
	use Text::Wrap;
	local ($Text::Wrap::columns, $Text::Wrap::huge) =
		($self->{wrap}, 'overflow');
	while (1) {
		($name, $value) = (shift, shift);	# get next arg pair
		last	unless $name or $value;		# done if both null
		$sequence .= Text::Wrap::wrap('',	# wrap lines using
			"\t",				# tab for indention
			$self->elem($name, $value)	# element
			);				# end the element
	}
	return $sequence;
}

package File::OM::ANVL;

our @ISA = ('File::OM');

sub elem {	# OM::ANVL
	my $self = shift;
	my ($name, $value, $elemnum, $lineno) = (shift, shift, shift, shift);
	my $s = '';

	defined($elemnum)	or $elemnum = 1;
	defined($lineno)	or $lineno = '1:';
	# Parse $lineno, which is empty or has form LinenumType, where
	# Type is either ':' (real element) or '#' (comment).
	my ($num, $type) =		# don't really need, as no comments
		$lineno =~ /^(\d*)\s*(.)/;

	if ($type eq '#') {
		# xxx this should be stacked
		$self->{element_name} = undef;	# indicates comment
		$s .= $self->comment_encode($value);
		# M_ELEMENT and C_ELEMENT would start here
		$s .= "\n";			# close comment
	}
	else {
		$self->{element_name} = $self->name_encode($name);
		$s .= $self->{element_name} . ':'
			. $self->value_encode($value);
		# M_ELEMENT and C_ELEMENT would start here
		$s .= "\n";
	}
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub orec {	# OM::ANVL
	my $self = shift;
	my ($recnum, $lineno) = (shift, shift);
	my $s = '';

	defined($recnum)	or $recnum = 1;
	defined($lineno)	or $lineno = '1:';
	# xxxx really? will someone pass that in?

	$self->{verbose} and
		$s .= "# from record $recnum, line $lineno\n";
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub crec {	# OM::ANVL
	my ($self, $recnum) = (shift, shift);
	defined($recnum)	or $recnum = 1;
	my $s = "\n";
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

# xxx anvl -m anvln? n=normalized?
sub ostream {	# OM::ANVL
	my $self = shift;
	# xxx preamble goes here, from other args?
	my $s = '';
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub cstream {	# OM::ANVL
	my $self = shift;
	my $s = '';
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub name_encode {	# OM::ANVL
	my ($self, $s) = (shift, shift);
	$s		or return '';
	$s =~ s/^\s+//;
	$s =~ s/\s+$//;		# trim both ends
	$s =~ s/\s+/ /g;	# squeeze multiple \s to one space
	$s =~ s/%/%%/g;		# to preserve literal %, double it
				# yyy must be decoded by receiver
	$s =~ s/:/%3a/g;	# URL-encode all colons (%cn)

	return $s;

	# XXXX must convert XML namespaces to make safe for ANVL
	# foo:bar ->? bar.foo (sort friendly, and puts namespace into
	#     proper subordinate position similar to dictionaries)?
	#     or if not namespace, foo:bar ->? foo%xxbar
}

sub value_encode {	# OM::ANVL

	my ($self, $s, $anvl_mode) = (shift, shift, shift);
	$s		or return '';
	$anvl_mode ||= 'ANVL';

	my $value = $s;			# save original value
	my ($initial_newlines) =	# save initial newlines
		$s =~ /^(\n*)/;		# always defined, often ""

	# value after colon starts with either preserved newlines,
	#	a space, or (if no value) nothing
	my $value_start = $initial_newlines || ($value ? ' ' : '');
	# xxxx is this the right place to enforce the space after ':'?

	# xxx is there a linear whitespace char class??
	#     problem is that \s includes \n
	$s =~ s/^\s+//;
	$s =~ s/\s+$//;		# trim both ends

	$s =~ s/%/%%/g;		# to preserve literal %, double it
				# yyy must be decoded by receiver
	if ($anvl_mode eq 'ANVLS') {
		$s =~ s/\|/%7c/g;	# URL-encode all vertical bars (%vb)
		$s =~ s/;/%3b/g;	# URL-encode all semi-colons (%sc)
		# XXX what about others, such as (:...) (=...)
	};
	return $value_start . $s;
}

sub comment_encode {	# OM::ANVL
	my ($self, $s) = (shift, shift);
	$s	or return '';
	$s =~ s/\n/\\n/g;			# escape \n
	return $s;
}

package File::OM::JSON;

our @ISA = ('File::OM');

sub elem {	# OM::JSON
	my $self = shift;
	my ($name, $value, $elemnum, $lineno) = (shift, shift, shift, shift);
	my $s = '';

	defined($elemnum)	or $elemnum = 1;
	defined($lineno)	or $lineno = '1:';
	# Parse $lineno, which is empty or has form LinenumType, where
	# Type is either ':' (real element) or '#' (comment).
	my ($num, $type) =
		$lineno =~ /^(\d*)\s*(.)/;

	$type eq '#'		and $name = '#';	# JSON pseudo-comment!
	$self->{element_name} = $self->name_encode($name);
	$elemnum > 1 || $self->{verbose} and	# either real element
		$s .= ',';	# or pseudo-comment element was used
	$s .= "\n" . $self->{indent};
	$s .= '"' . $self->{element_name} . '": "'
		. $self->value_encode($value) . '"';
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub orec {	# OM::JSON
	my $self = shift;
	my ($recnum, $lineno) = (shift, shift);
	my $s = '';

	defined($recnum)	or $recnum = 1;
	defined($lineno)	or $lineno = '1:';
	# xxxx really? will someone pass that in?

	$recnum > 1		and $s .= ',';
	$s .= "\n" . $self->{indent} . '{';		# use indent and
	$self->{verbose} and
		$s .= qq@ "#": "from record $recnum, line $lineno"@;
	$self->{indent} =~ s/$/$self->{indent_step}/;	# increase indent
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub crec {	# OM::JSON
	my ($self, $recnum) = (shift, shift);
	defined($recnum)	or $recnum = 1;
	$self->{indent} =~ s/$self->{indent_step}$//;	# decrease indent
	my $s = "\n" . $self->{indent} . '}';		# and use indent
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub ostream {	# OM::JSON
	my $self = shift;
	$self->{indent_step} ||= '  ';		# standard indent width

	$self->{indent} = $self->{indent_step};		# current indent width
	my $s = '[';
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub cstream {	# OM::JSON
	my $self = shift;
	$self->{indent} =~ s/$self->{indent_step}$//;	# decrease indent
	my $s = "\n]\n";
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub name_encode {	# OM::JSON
	my ($self, $s) = (shift, shift);
	$s	or return '';
	$s =~ s/(["\\])/\\$1/g;			# excape " and \
	$s =~ s{
		([\x00-\x1f])			# escape all control chars
	}{
		sprintf("\\u00%02x", ord($1))	# replacement hex code
	}xeg;
	return $s;
}

sub value_encode {	# OM::JSON
	my $self = shift;
	return $self->name_encode(@_);
}

sub comment_encode {	# OM::JSON
	my $self = shift;
	return $self->name_encode(@_);
}

package File::OM::Plain;

our @ISA = ('File::OM');

sub elem {	# OM::Plain
	my $self = shift;
	my ($name, $value, $elemnum, $lineno) = (shift, shift, shift, shift);
	my $s = '';

	defined($elemnum)	or $elemnum = 1;
	defined($lineno)	or $lineno = '1:';
	# Parse $lineno, which is empty or has form LinenumType, where
	# Type is either ':' (real element) or '#' (comment).
	my ($num, $type) =		# don't really need, as no comments
		$lineno =~ /^(\d*)\s*(.)/;

	if ($type ne '#') {
		$self->{element_name} = $name;
		$s .= $value . "\n"		if $value;
	}
	else {				# Plain pseudo-comment!
		$self->{element_name} = '#';
		$s .= " $value\n"		if $value;
	}
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub orec {	# OM::Plain
	my $self = shift;
	my ($recnum, $lineno) = (shift, shift);
	my $s = '';

	defined($recnum)	or $recnum = 1;
	defined($lineno)	or $lineno = '1:';

	$self->{verbose} and
		$s .= "# from record $recnum, line $lineno\n";
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub crec {	# OM::Plain
	my ($self, $recnum) = (shift, shift);
	defined($recnum)	or $recnum = 1;
	my $s = "\n";
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub ostream {	# OM::Plain
	my $self = shift;
	my $s = '';
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
	#$$o{indent_step} ||= '';		# standard indent width
	#$$o{indent} = $$o{indent_step};		# current indent width
}

sub cstream {	# OM::Plain
	my $self = shift;
	my $s = '';
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub name_encode {	# OM::Plain
	my ($self, $s) = (shift, shift);
	return $s;
}

sub value_encode {	# OM::Plain
	my ($self, $s) = (shift, shift);
	return $s;
}

sub comment_encode {	# OM::Plain
	my ($self, $s) = (shift, shift);
	return $s;
}

package File::OM::Turtle;

our @ISA = ('File::OM');

sub elem {	# OM::Turtle

	my $self = shift;
	my ($name, $value, $elemnum, $lineno) = (shift, shift, shift, shift);
	my $s = '';

	defined($elemnum)	or $elemnum = 1;
	defined($lineno)	or $lineno = '1:';
	# Parse $lineno, which is empty or has form LinenumType, where
	# Type is either ':' (real element) or '#' (comment).
	my ($num, $type) =		# don't really need, as no comments
		$lineno =~ /^(\d*)\s*(.)/;

	if ($type eq '#') {
		$self->{element_name} = undef;	# indicates comment
		$s .= "\n" . $self->comment_encode($value) . "\n";
		#
		# To create syntactically correct Turtle, we need
		# to end a comment with a newline at the end; this
		# can, however, result in ugly Turtle, since the
		# ';' or '.' that ends an element will have to
		# follow on the next line after that, and the only
		# remedy is to peek ahead at the next element.
	}
	else {
		$self->{element_name} = $self->name_encode($name);
		$elemnum > 1		and $s .= ' ;';
		$s .= "\n" . $self->{turtle_indent};
		$s .= $self->{turtle_stream_prefix}
			. ":$self->{element_name} "
			. '"""'
			. $self->value_encode($value)
			. '"""';
	}
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub orec {	# OM::Turtle
	my $self = shift;
	my ($recnum, $lineno) = (shift, shift);
	my $s = '';

	defined($recnum)	or $recnum = 1;
	defined($lineno)	or $lineno = '1:';

	$self->{verbose} and
		$s .= "# from record $recnum, line $lineno\n";
	defined($self->{subject}) or
		$self->{subject} = $self->{turtle_nosubject};
	$s .= "<$self->{subject}>";

	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub crec {	# OM::Turtle
	my ($self, $recnum) = (shift, shift);
	defined($recnum)	or $recnum = 1;
	my $s = " .\n\n";
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub ostream {	# OM::Turtle
	my $self = shift;
	# add the Turtle preamble
	my $s = "\@prefix $self->{turtle_stream_prefix}: <"
		. $self->{turtle_predns} .  "> .\n";
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub cstream {	# OM::Turtle
	my $self = shift;
	my $s = '';
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub name_encode {	# OM::Turtle
	my ($self, $s) = (shift, shift);
	$s	or return '';
	$s =~ s/(["\\])/\\$1/g;
	return $s;
	# \" \\
}

sub value_encode {	# OM::Turtle
	my ($self, $s) = (shift, shift);
	$s	or return '';
	$s =~ s/(["\\])/\\$1/g;
	return $s;
}

sub comment_encode {	# OM::Turtle
	my ($self, $s) = (shift, shift);
	$s	or return '';
	$s =~ s/\n/\\n/g;			# escape \n
	return $s;
}

package File::OM::XML;

our @ISA = ('File::OM');

sub elem {	# OM::XML

	my $self = shift;
	my ($name, $value, $elemnum, $lineno) = (shift, shift, shift, shift);
	my $s = '';

	defined($elemnum)	or $elemnum = 1;
	defined($lineno)	or $lineno = '1:';
	# Parse $lineno, which is empty or has form LinenumType, where
	# Type is either ':' (real element) or '#' (comment).
	my ($num, $type) =
		$lineno =~ /^(\d*)\s*(.)/;
	if ($type eq '#') {
		# xxx this should be stacked
		$self->{element_name} = undef;	# indicates comment
		$s .= "$self->{indent}<!-- " .
			$self->comment_encode($value);
		# M_ELEMENT and C_ELEMENT would start here
		$s .= " -->\n";			# close comment
	}
	else {
		# xxx we're saving this to no end; in full form
		# (open and close element) the element name would
		# be saved on a stack and the indent increased
		# across all outformat types.
		#
		$self->{element_name} = $self->name_encode($name);
		$s .= $self->{indent} . "<$self->{element_name}>"
			. $self->value_encode($value);
		# M_ELEMENT and C_ELEMENT would start here
		$s .= "</$self->{element_name}>\n";
	}
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub orec {	# OM::XML
	my $self = shift;
	my ($recnum, $lineno) = (shift, shift);

	defined($recnum)	or $recnum = 1;
	defined($lineno)	or $lineno = '1:';

	my $s .= $self->{indent} .			# use indent and
		"<$self->{xml_record_name}>";
	$self->{indent} =~ s/$/$self->{indent_step}/;	# increase indent
	$self->{verbose} and
		$s .= "   <!-- from record $recnum, line $lineno -->";
	$s .= "\n";
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub crec {	# OM::XML
	my ($self, $recnum) = (shift, shift);
	defined($recnum)	or $recnum = 1;	# not using now? yyy
	$self->{indent} =~ s/$self->{indent_step}$//;	# decrease indent
	my $s = $self->{indent} .			# and use indent
		"</$self->{xml_record_name}>\n";
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub ostream {	# OM::XML
	my $self = shift;
	# xxx preamble goes here, from other args?
# xxx anvl -m anvln? n=normalized?

	$self->{indent} = $self->{indent_start};	# current indent width
	$self->{indent} =~ s/$/$self->{indent_step}/;	# increase indent
	my $s = "<$self->{xml_stream_name}>\n";
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub cstream {	# OM::XML
	my $self = shift;
	$self->{indent} =~ s/$self->{indent_step}$//;	# decrease indent
	my $s = "</$self->{xml_stream_name}>\n";
	$self->{outhandle} and
		return (print { $self->{outhandle} } $s)
	or
		return $s;
}

sub name_encode {	# OM::XML
	my $self = shift;
	local $_ = shift(@_) || '';

	s/&/&amp;/g;
	s/'/&apos;/g;
	s/</&lt;/g;
	s/>/&gt;/g;
	s/\\/\\\\/g;
	s/"/\\"/g;

	return $_;

	# &apos; &amp; &lt; &gt; (unparsed \" \\ )
	# XXXX CDATA sections begin with the string " <![CDATA[  "
	# and end with the string " ]]>  "
}

sub value_encode {	# OM::XML
	my $self = shift;
	return $self->name_encode(@_);
}

sub comment_encode {	# OM::XML
	my ($self, $s) = (shift, shift);
	$s	or return '';
	$s =~ s/-->/--&gt;/g;
	return $s;
}

1;

__END__

=head1 NAME

File::OM - output multiplexer routines

=head1 SYNOPSIS

 use File::OM;              # to import routines into a Perl script

 $om = File::OM->new(       # make output object that creates strings in
       $format, {           # XML, Turtle, JSON, ANVL, or Plain formats
   outhandle => *STDOUT,    # (opt) print string instead of returning it
   verbose => 1 });         # (opt) also output record and line numbers

 $om->ostream();            # open stream

 $om->cstream();            # close stream

 $om->orec(                 # open record
       $recnum,             # record number (default 1)
       $lineno);            # input line number (default 1)

 $om->crec(                 # close record
       $recnum);            # record number (default 1)

 $om->elem(                 # output an entire element
       $name,               # string representing element name
       $value,              # string representing element value
       $elemnum,            # element number (default 1)
       $lineno);            # starting input line number (default '1:')

 $om->elems(                # output elements; wrap ANVL/Plain/XML lines
       $name,               # string representing first element name
       $value,              # string representing first element value
       ...);                # other element names and values

 $om->name_encode($s);      # encode a name
 $om->value_encode($s);     # encode a value
 $om->comment_encode($s);   # encode a comment or pseudo-comment

 om_opt_defaults();         # get hash reference with factory defaults

=head1 DESCRIPTION

The B<OM> (Output Multiplexer) Perl module provides a general output
formatting framework for data that can be represented as records
consisting of elements, values, and comments.  Specific conversions are
possible to XML, Turtle, JSON, and "Plain" unlabeled text.

The internal element structure is currently identical to the structure
returned by L<File::ANVL::anvl_recarray>.  The first triple of the
returned array is special in that it describes the origin of the record;
its elements are

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
comment is contatined in the value.

B<OM> presents an object oriented interface.  The object constructor
takes a format argument and returns C<undef> if the format is unknown.
The returned object has methods for creating format-appropriate output
corresponding (currently) to five output modes; for a complete
application of these methods, see L<File::ANVL::anvl_om>.

Constructor options include 'verbose', which causes the methods to insert
record and line numbers as comments or pseudo-comments (e.g., for JSON,
an extra element called "#" since JSON doesn't support comments).
Normally output is returned as a string, but if the 'outhandle' option
(defaults to '') contains a file handle, for example,

     { outhandle => *STDOUT }

the string will be printed to the file handle and the method will return
the status of the print call.  Constructor options and defaults:

 {
 outhandle        => '',        # return string instead of printing it
 indent_start     => '',        # overall starting indent
 indent_step      => '  ',      # how much to increment/decrement indent

 # Format specific options.
 turtle_indent    => '    ',    # turtle has one indent width
 turtle_predns    =>            # turtle predicate namespaces
        'http://purl.org/kernel/elements/1.1/',
 turtle_nosubject => 'default', # a default subject (change this)
 turtle_subjelpat => '',        # pattern for matching subject element
 turtle_stream_prefix => 'erc', # symbol we use for turtle
 wrap             => 72,        # wrap text to 72 cols (ANVL, Plain, XML)
 xml_stream_name  => 'recs',    # for XML output, stream tag
 xml_record_name  => 'rec',     # for XML output, record tag

 # Used to maintain object state.
 indent           => '',        # current ident
 elemsref         => [],        # one array to store record elements
 }

In this release of the B<OM> package, objects carry very limited state
information.  A sense of current indention level is maintained, but there
is no stack of "open elements".  Right now there is only a "whole element
at once" method (C<elem()>) that takes a name and value arguments to
construct a complete element.  Future releases may support methods for
opening and closing elements.

Most method arguments are optional, but for formats that put separators
before every element or record except for the first one (e.g., JSON uses
commas), the default values will not produce satisfactory results.  The
C<$lineno> arguments refer to input line numbers that may be useful with
the 'verbose' option and creating helpful diagnostic messages.

The caller may elect to use none or all of the methods.  It would not
be unusual for an application to use only the C<elem()> method for
output, especially when another application will be wrapping that output
for its own purposes.

=head1 SEE ALSO

A Name Value Language (ANVL)
	L<http://www.cdlib.org/inside/diglib/ark/anvlspec.pdf>

=head1 HISTORY

This is a beta version of OM package.  It is written in Perl.

=head1 AUTHOR

John A. Kunze I<jak at ucop dot edu>

=head1 COPYRIGHT AND LICENSE

Copyright 2009-2010 UC Regents.  Open source BSD license.

=head1 PREREQUISITES

Perl Modules: L<Text::Wrap>

Script Categories:

=pod SCRIPT CATEGORIES

UNIX : System_administration

=cut
