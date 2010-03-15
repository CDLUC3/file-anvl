#########################

use Test::More tests => 17;		# adjust number after adding tests

use strict;
use File::ANVL;

my $t = "a_test";
#$ENV{'SHELL'} = "/bin/sh";

#########################

{ 	# anvl tests

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
     . anvl_fmt("where", "identifier")
     . "\n";                # 2nd newline in a row terminates record

like $anvl_record, '/^erc:\nwho:.*what:.*\nwhen:.*\nwhere:.*\n\n$/s',
'well-formed anvl record';

my $aref_nam_val;	# array reference for returned name/value pairs

is anvl_split($anvl_record, $aref_nam_val, 1), "", 'easy split, strict';

is $$aref_nam_val[0], "erc", 'valueless label';

is $$aref_nam_val[1], "", 'valueless value';

is $$aref_nam_val[2], "who", 'second label';

is $$aref_nam_val[3], "creator1; creator2; creator3", 'second value';

my $offbeat_record = "a: b
c d";

$aref_nam_val = undef;
my $m = anvl_split($offbeat_record, $aref_nam_val, 1);
is defined($aref_nam_val), "", 'offbeat record, strict mode no split';

like $m, '/unindented/', 'offbeat record, strict mode error';

$m = anvl_split($offbeat_record, $aref_nam_val);
is defined($aref_nam_val), 1, 'offbeat record, default no strict mode split';

like $m, '/warning: indenting/', 'offbeat record, no strict mode warning';

is anvl_split("a: b
#foo
c: d
#  bar
e: f", $aref_nam_val), "", 'record with comments';

is scalar(@$aref_nam_val), 6, 'correct elem count for record with comments';

}
