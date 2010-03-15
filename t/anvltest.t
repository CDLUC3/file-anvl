use 5.006;
use Test::More qw( no_plan );

use strict;
use warnings;
use File::ANVL;

{ 	# ANVL tests

is anvl_fmt(" 
a b::d

", "  	
e f g
h i

"), "a b%3a%3ad: e f g
	h i
", 'trim plus %encode';

is anvl_fmt(" label", "  now is"),
"label: now is
", 'one-line trim with newline added';

is anvl_fmt("
label", " now is
   a
   b
   c d"), "label: now is
	   a
	   b
	   c d
", 'multi-line, initial newline trim';

is anvl_fmt("label", "
now is
   a
   b
   c d", 1), "label:
	now is
	   a
	   b
	   c d
", 'multi-line preserving first newline';

is anvl_fmt("label", "now is the time for all good men to come to the aid of the party again and again and again."),
"label: now is the time for all good men to come to the aid of the party
	again and again and again.
", 'multi-line wrap';

my $anvl_record =		# Example use of anvl_fmt()
       anvl_fmt("erc")
     . anvl_fmt("who", "creator1;
creator2; creator3")
     . anvl_fmt("what", "This is a very long involved complicated extended, very long involved complicated extended, very long involved complicated extended, very long involved complicated extended, very long involved complicated extended, very long involved complicated extended title")
     . anvl_fmt("when", "18990304")
     . anvl_fmt("where", "http://foo.bar.com/ab/cd.efg")
     . "\n";                # 2nd newline in a row terminates record

#xxx print "rec=$anvl_record";

like $anvl_record, '/^erc:\nwho:.*what:.*\nwhen:.*\nwhere:.*\n\n$/s',
'well-formed anvl record';

my $m = anvl_recsplit("foo", "dummy");
like $m, qr/array/, 'recsplit message about 2nd arg referencing an array';

my @elems;
is anvl_recsplit($anvl_record, \@elems, 1), "", 'easy split, strict';

is $elems[0], "erc", 'valueless label';

is $elems[1], "", 'valueless value';

is $elems[2], "who", 'second label';

is $elems[3], "creator1; creator2; creator3", 'second value';

my %read_anvl = @elems;
is $read_anvl{when}, "18990304", 'third element';

is $read_anvl{where}, "http://foo.bar.com/ab/cd.efg", 'fourth element';

my $offbeat_record = "a: b
c d";

$m = anvl_recsplit($offbeat_record, \@elems, 1);
like $m, qr/^error:/, 'indention glitch, strict mode no split';

$m = anvl_recsplit($offbeat_record, \@elems);
like $m, qr/^warning:/, 'indention glitch, default no strict mode warning';

is anvl_recsplit("a: b
#foo
c: d
#  bar
e: f", \@elems), "", 'record with comments';

is scalar(@elems), 6, 'correct elem count for record with comments';

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

{	# anvl_encode/anvl_decode

is anvl_encode("now:this|that"), 'now%cnthis%vbthat', 'simple encode';

is anvl_decode("now%cnthis%vbthat"), 'now:this|that', 'simple decode';

}
