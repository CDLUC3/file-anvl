#########################

use Test::More tests => 41;		# adjust number after adding tests

use strict;
use File::ANVL;
use File::Path;

my $t = "namaste_test";
#$ENV{'SHELL'} = "/bin/sh";

#########################

{	# file_value tests

mkdir $t;
my $x = '   /hi;!echo *; e/fred/foo/pbase        ';
my $y;

is file_value(">$t/fvtest", $x), "", 'write returns ""';

is file_value("<$t/fvtest", $y, "raw"), "", 'read returns ""';

is $x, $y, 'raw read of what was written';

my $z = (-s "$t/fvtest");
is $z, length($x), "all bytes written";

file_value("<$t/fvtest", $x);
is $x, '/hi;!echo *; e/fred/foo/pbase', 'default trim';

file_value("<$t/fvtest", $x, "trim");
is $x, '/hi;!echo *; e/fred/foo/pbase', 'explicit trim';

file_value("<$t/fvtest", $x, "untaint");
is $x, 'hi', 'untaint test';

file_value("<$t/fvtest", $x, "trim", 0);
is $x, '/hi;!echo *; e/fred/foo/pbase', 'trim, unlimited';

file_value("<$t/fvtest", $x, "trim", 12);
is $x, '/hi;!echo', 'trim, max 12';

file_value("<$t/fvtest", $x, "trim", 12000);
is $x, '/hi;!echo *; e/fred/foo/pbase', 'trim, max 12000';

like file_value("<$t/fvtest", $x, "foo"), '/must be one of/',
'error message test';

like file_value("$t/fvtest", $x),
'/file .*fvtest. must begin.*/', 'force use of >, <, or >>';

is file_value(">$t/Whoa\\dude:!
  Adventures of HuckleBerry Finn", "dummy"), "", 'write to weird filename';

rmtree($t);

}

#########################

{	# elide tests

is elide("abcdefghi"), "abcdefghi", 'simple no-op';

is elide("abcdefghijklmnopqrstuvwxyz", "7m", ".."),
"ab..xyz", 'truncate explicit, middle';

is elide("abcdefghijklmnopqrstuvwxyz"),
"abcdefghijklmn..", 'truncate implicit, end';

is elide("abcdefghijklmnopqrstuvwxyz", 22),
"abcdefghijklmnopqrst..", 'truncate explicit, end';

is elide("abcdefghijklmnopqrstuvwxyz", 22, ".."),
"abcdefghijklmnopqrst..", 'truncate explicit, end, explicit ellipsis';

is elide("abcdefghijklmnopqrstuvwxyz", "22m"),
"abcdefghi...qrstuvwxyz", 'truncate explicit, middle';

is elide("abcdefghijklmnopqrstuvwxyz", "22m", ".."),
"abcdefghij..qrstuvwxyz", 'truncate explicit, middle, explicit ellipsis';

is elide("abcdefghijklmnopqrstuvwxyz", "22s"),
"..ghijklmnopqrstuvwxyz", 'truncate explicit, start';

# XXXX this +4% test isn't really implemented
is elide("abcdefghijklmnopqrstuvwxyz", "22m+4%", "__"),
"abcdefghij__qrstuvwxyz", 'truncate explicit, middle, alt. ellipsis';

}

#########################

{ 	# namaste tests

mkdir $t;
chdir $t;

my $namy = "noid_0.6";
is set_namaste(0, "pairtree_0.3"), "", 'short namaste tag';
is set_namaste(0, $namy), "", 'second, repeating namaste tag';

my $namx = "Whoa/dude:!
  Adventures of HuckleBerry Finn";

is set_namaste(1, $namx), "", 'longer stranger tag';

my @namtags = get_namaste();
ok scalar(@namtags) eq 9, 'got correct number of tags';

is $namtags[8], $namx, 'read back longer stranger tag';

is scalar(get_namaste("9")), "0", 'no matching tags';

@namtags = get_namaste("0");
is $namtags[2], $namy, 'read repeated namaste tag, which glob sorts first';

my ($num, $fname, $fvalue, @nums);
@namtags = get_namaste();
while (defined($num = shift(@namtags))) {
	$fname = shift(@namtags);
	$fvalue = shift(@namtags);
	unlink($fname);
	push(@nums, $num);
}
is join(", ", @nums), "0, 0, 1", 'tag num sequence extracted from array';

is scalar(get_namaste()), "0", 'tags all unlinked';

#XXX need lots more tests

chdir("..");
rmtree($t);

}

#########################

{ 	# nam tests

my $this_dir = ".";
my $nam_bin = "blib/script/nam";
my $nam_cmd = (-x $nam_bin ? $nam_bin : "../$nam_bin") . " -d $this_dir ";
my ($x);

#system("$nam_cmd dbcreate tst1.rde long 13030 cdlib.org noidTest >/dev/null");

$x = `$nam_cmd delall`;
is $x, "", 'nam delall to clean out test dir';

$x = `$nam_cmd set 0 foobar`;
chop($x);
is $x, "", 'set of dir_type';

#print "nam_cmd=$nam_cmd\n", `ls -t`;

$x = `$nam_cmd get 0`;
chop($x);
is $x, "foobar", 'get of dir_type';

$x = `$nam_cmd set 1 'Mark Twain'`;
chop($x);
is $x, "", 'set of "who"';

$x = `$nam_cmd get 1`;
chop($x);
is $x, "Mark Twain", 'get of "who"';

$x = `$nam_cmd set 2 'Adventures of Huckleberry Finn' 13m ___`;
chop($x);
is $x, "", 'set of long "what" value, with elision';

$x = `$nam_cmd get 2`;
chop($x);
is $x, 'Adventures of Huckleberry Finn', 'get of long "what" value';

$x = `$nam_cmd -vf anvl get 2`;
chop($x);
like $x, '/2=Adven___ Finn/', 'get filename with "-f anvl" and -v comment';

$x = `$nam_cmd --verbose --format xml get 2`;
chop($x);
like $x, '/2=Adven___ Finn -->/', 'get with long options and "xml" comment';

$x = `$nam_cmd delall`;
is $x, "", 'final nam delall to clean out test dir';

}
