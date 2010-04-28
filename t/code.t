use 5.006;
use Test::More qw( no_plan );

use strict;
use warnings;

my $script = "anvl";		# script we're testing

# as of 2009.08.27  (SHELL stuff, remake_td, Config perlpath)
#### start boilerplate for script name and temporary directory support

use Config;
$ENV{SHELL} = "/bin/sh";
my $td = "td_$script";		# temporary test directory named for script
# Depending on circs, use blib, but prepare to use lib as fallback.
my $blib = (-e "blib" || -e "../blib" ?	"-Mblib" : "-Ilib");
my $bin = ($blib eq "-Mblib" ?		# path to testable script
	"blib/script/" : "") . $script;
my $perl = $Config{perlpath} . $Config{_exe};	# perl used in testing
my $cmd = "2>&1 $perl $blib " .		# command to run, capturing stderr
	(-x $bin ? $bin : "../$bin") . " ";	# exit status in $? >> 8

my ($rawstatus, $status);		# "shell status" version of "is"
sub shellst_is { my( $expected, $output, $label )=@_;
	$status = ($rawstatus = $?) >> 8;
	$status != $expected and	# if not what we thought, then we're
		print $output, "\n";	# likely interested in seeing output
	return is($status, $expected, $label);
}

use File::Path;
sub remake_td {		# make $td with possible cleanup
	-e $td			and remove_td();
	mkdir($td)		or die "$td: couldn't mkdir: $!";
}
sub remove_td {		# remove $td but make sure $td isn't set to "."
	! $td || $td eq "."	and die "bad dirname \$td=$td";
	eval { rmtree($td); };
	$@			and die "$td: couldn't remove: $@";
}

#### end boilerplate

use File::ANVL qw(:all);	# import everything in EXPORT_OK

{	# anvl_encode/anvl_decode

is anvl_encode("now:this|that"), 'now%cnthis%vbthat', 'simple encode';

is anvl_decode("now%cnthis%vbthat"), 'now:this|that', 'simple decode';

is anvl_decode("a%{ b c d %}e"), 'abcde', 'one expansion block';

is anvl_decode("%{nospaces%} u %{ a
b	c
d
%}%{b = c%}th%{%}at"), 'nospaces u abcdb=cthat', 'several expansion blocks';

#{
is anvl_decode("now%}this%{that"), 'nowthisthat',
	'mismatched expansion block delimiters removed';
#}

is anvl_decode('http://foo.bar.org/node%{
           ? db = foo
           & start = 1
           & end = 5
           & buf = 2
           & query = foo + bar + zaf
       %}'),
'http://foo.bar.org/node?db=foo&start=1&end=5&buf=2&query=foo+bar+zaf',
	'example expansion block URL from documentation';

use File::OM;

my $om = File::OM::XML->new();
is $om->name_encode('ab<cd>ef&"hi\'j'), 'ab&lt;cd&gt;ef&amp;\\"hi&apos;j',
	'xml name encode';

is $om->value_encode('ab<cd>ef&"hi\'j'), 'ab&lt;cd&gt;ef&amp;\\"hi&apos;j',
	'xml value encode';

is $om->comment_encode('ab-->ef"hi\'j'), 'ab--&gt;ef"hi\'j',
	'xml comment encode';

$om = File::OM->new("turtle");
# \" \\
is $om->value_encode('ab<cd>ef&"hi\\j'), 'ab<cd>ef&\\"hi\\\\j',
	'turtle value encode';

$om = File::OM->new("jSon");
is $om->name_encode('ab<cd>ef&"hi\\j'),
	'ab<cd>ef&\\"hi\\\\j', 'json name encode';

is $om->value_encode("a	b\nc"), 'a\u0009b\u000ac',
	'json value encode with control chars';

}

{	# getlines and trimlines

remake_td();
 
# create and open a file with 3 records and whitespace before and after
my $recstream = '	 
    

a:b
c:d



e:f
g:h


i:j

    


';

my $x = `echo "$recstream" > $td/file`;
open "IN", "< $td/file"		or die "couldn't open $td/file";

my ($linenum, $rec, $wslines, $rrlines, @newlines);

$linenum = 1;
$rec = getlines(*IN);
$rec = trimlines($rec, \$wslines, \$rrlines);
$linenum += $wslines;
like $linenum.$rec, qr/4a:b\nc:d\n\n/, 'first getlines record on line 4';

$linenum += $rrlines;
$rec = getlines(*IN);
$rec = trimlines($rec, \$wslines, \$rrlines);
$linenum += $wslines;
like $linenum.$rec, qr/9e:f\ng:h\n\n/, 'second getlines record on line 9';

#$linenum += scalar(@newlines = $rec =~ /\n/g);
$linenum += $rrlines;
$rec = getlines(*IN);
$rec = trimlines($rec, \$wslines, \$rrlines);
$linenum += $wslines;
#$rec =~ s/^(\s+)//s	and $linenum += scalar(@newlines = $1 =~ /\n/g);
like $linenum.$rec, qr/13i:j\n\n/, 'third getlines record on line 13';

#$linenum += scalar(@newlines = $rec =~ /\n/g);
$linenum += $rrlines;
$rec = getlines(*IN);
$rec = trimlines($rec, \$wslines, \$rrlines);
is $rec, undef, 'fourth getlines call hits almost eof (blank record)';
$linenum += $wslines;	# where next rec would start if there was one

is $linenum-1, 18, 'getlines has returned total of 18 lines';

is $rec, undef, 'fifth getlines call hits real eof';

#is trimlines("a:b", \$wslines), "a:b\n\n",
#	'trimlines adds one newline, one optional arg';
#
#is trimlines("a:b\n"), "a:b\n\n",
#	'trimlines adds two newlines, no optional args';
#
#is trimlines("\n\n\na:b"), "a:b\n\n",
#	'trimlines adds 2 newlines, strips 3 newlines';

$wslines = $rrlines = undef;
is trimlines("\n\n  \n  ", \$wslines, \$rrlines), undef,
	'trimlines strips whitespace with premature EOF and returns undef';

is $wslines, 3, 'trimlines returns undef but still counted blank lines';
is $rrlines, 0, 'trimlines returns undef but still defined record linecount';

$x = `cat $td/file | $cmd --verbose --comments`;
like $x, qr/record 3, line 13/, 'stdin test for getlines (with anvl)';

$x = `$cmd --verbose --comments $td/file $td/file $td/file`;
like $x, qr{
line\ 4 .* line\ 22 .* line\ 27 .* line\ 31 .* line\ 40 .*
}sx, '3-file test for getlines (with anvl)';

remove_td();
# remove_td();

}

{	# anvl_name_naturalize

is anvl_name_naturalize("Smith, John"), "Smith, John",
	'naturalize, no final comma';

is anvl_name_naturalize("Smith, III, John,"), "John Smith, III",
	'naturalize, with suffix';
#print anvl_name_naturalize("Smith, III, John,"), "\n";

is anvl_name_naturalize("Mao Tse Tung,"), "Mao Tse Tung",
	'naturalize, no internal comma';

}

{	# --find and --show

remake_td();

# create and open a file with 3 records and whitespace before and after
my $recstream = '	 
    
a: now
c: is
e: the
g: time

a: for
c: all
e: good
g: men

a: to
c: come
e: to
g: the

a: aid
c: of
e: the
g: party
';
my $x = `echo "$recstream" > $td/file`;

$x = `$cmd --find 'the' $td/file`;
like $x, qr/e: the.*\n\n.*g: the.*\n\n.*e: the/s,
	'find 3 records';

$x = `$cmd --show 'the' $td/file`;
is $x, "e: the\n\n\ng: the\n\ne: the\n\n", 'show 3 lines in 4 records';

$x = `$cmd --find '(now|aid)' --show '^g' $td/file`;
is $x, "g: time\n\ng: party\n\n", 'find and show with regexes';

remove_td
}
