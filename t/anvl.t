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

{	# ANVL module tests

use File::OM;
my $om = File::OM->new("anvl");

is $om->elems("
a b::d

", "  	
e f g
h i

"), "a b%3a%3ad: e f g
	h i
", 'trim plus %encode';

is $om->elems(" label", "  now is"),
"label: now is
", 'one-line trim with newline added';

is $om->elems("
label", " now is
   a
   b
   c d"), "label: now is
	   a
	   b
	   c d
", 'multi-line, initial newline trim';

is $om->elems("label", "
now is
   a
   b
   c d"), "label:
	now is
	   a
	   b
	   c d
", 'multi-line preserving first newline';

is $om->elems("label", "now is the time for all good men to come to the aid of the party again and again and again."),
"label: now is the time for all good men to come to the aid of the party
	again and again and again.
", 'multi-line wrap';

my $anvl_record =		# POD example use of anvl_fmt()
       $om->elems("erc", "",
	"who", "creator1;
creator2; creator3",
	"what", "This is a very long involved complicated extended, very long involved complicated extended, very long involved complicated extended, very long involved complicated extended, very long involved complicated extended, very long involved complicated extended title",
	"when", "18990304",
	"where", "http://foo.bar.com/ab/cd.efg"
	) . "\n";                # 2nd newline in a row terminates record

like $anvl_record, '/^erc:\nwho:.*what:.*\nwhen:.*\nwhere:.*\n\n$/s',
	'well-formed anvl record in one call';

$anvl_record =			# verbose version of POD example
       $om->elems("erc")
     . $om->elems("who", "creator1;
creator2; creator3")
     . $om->elems("what", "This is a very long involved complicated extended, very long involved complicated extended, very long involved complicated extended, very long involved complicated extended, very long involved complicated extended, very long involved complicated extended title")
     . $om->elems("when", "18990304")
     . $om->elems("where", "http://foo.bar.com/ab/cd.efg")
     . "\n";                # 2nd newline in a row terminates record

like $anvl_record, '/^erc:\nwho:.*what:.*\nwhen:.*\nwhere:.*\n\n$/s',
	'well-formed anvl record in multiple calls';

my $m = File::ANVL::anvl_recarray("foo", "dummy");
like $m, qr/an array/, 'recarray message about 2nd arg referencing an array';

#$m = anvl_recsplit("foo", "dummy");
#like $m, qr/array/, 'recsplit message about 2nd arg referencing an array';

my @elems;
#is anvl_recsplit($anvl_record, \@elems, 1), "", 'easy split, strict';
is File::ANVL::anvl_recarray($anvl_record, \@elems), "",
	'easy recarray split, all defaults';

is $elems[0], "ANVL", 'record preamble';
is $elems[3], "1:", 'first line number';
is $elems[4], "erc", 'valueless label';
is $elems[5], "", 'valueless value';
is $elems[6], "2:", 'second line number';
is $elems[7], "who", 'first real element label';
is $elems[8], "creator1; creator2; creator3", 'first real element value';
is $elems[13], "when", 'third element label';
is $elems[14], "18990304", 'third element value';
is $elems[16], "where", 'fourth label';
is $elems[17], "http://foo.bar.com/ab/cd.efg", 'fourth value';

#my %read_anvl = @elems;
#is $read_anvl{when}, "", 'third element';
#is $read_anvl{where}, "", 'fourth element';

my $offbeat_record = "a: b
c d";

#$m = anvl_recsplit($offbeat_record, \@elems, 1);
$m = File::ANVL::anvl_recarray($offbeat_record, \@elems, 1, {autoindent => 0});
like $m, qr/^error:/, 'indention glitch, strict mode no autoindent';

#$m = anvl_recsplit($offbeat_record, \@elems);
$m = File::ANVL::anvl_recarray($offbeat_record, \@elems, 1);
like $m, qr/^warning:/, 'indention glitch, default autoindent mode warning';

my $r1 = 'a: b
#foo
c: d
#  bar
e: f
# note to self
';

is File::ANVL::anvl_recarray($r1, \@elems, 1, {comments=>1}), "",
	'record with final comment, comments kept';
is scalar(@elems), 21, 'correct elem count for record, comments kept';

is File::ANVL::anvl_recarray($r1, \@elems), "", 'record, comments stripped';
is scalar(@elems), 12, 'correct elem count for record, no comments';

is File::ANVL::anvl_recarray("
a: b c
d:  e
  f
g:
  h i
", \@elems), "", '3 element record from pod example';

my ($s, $i);
for ($i = 4; $i < $#elems; $i += 3) {
    $s .= "[$elems[$i] <- $elems[$i+1]] ";
}
is $s, '[a <- b c] [d <- e f] [g <- h i] ', '3 elements reformatted';;

# yyy would be nice to test anvl_om with string return (not print)
}
