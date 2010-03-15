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

use File::OM;

{	# OM object tests

my $om = File::OM->new("Xyz");
is $om, undef, 'failed to make a nonsense object';

$om = File::OM->new("Plain");
is ref($om), 'File::OM::Plain', 'made a File::OM::Plain object';

is $om->elem('foo', 'bar'), 'bar
', 'simple Plain element';

$om = File::OM->new("XML", { verbose => 1 });
is ref($om), 'File::OM::XML', 'made a File::OM::XML object';

is $om->elem('foo', 'bar'), '<foo>bar</foo>
', 'simple XML element';

like $om->orec(), qr/<rec>.*record 1, line 1/,
	'XML verbose record start with defaults for recnum and lineno';

$om = File::OM->new('JSON');
is ref($om), 'File::OM::JSON', 'made a File::OM::JSON object';

is $om->elem('foo', 'bar'), '
"foo": "bar"', 'simple JSON element';

$om = File::OM->new('Turtle');
is ref($om), 'File::OM::Turtle', 'made a File::OM::Turtle object';

is $om->orec('a:b'), '<default>', 'orec for Turtle with default';

is $om->elem('foo', 'bar'), '
    erc:foo """bar"""', 'simple Turtle element';

$om = new File::OM::ANVL;
is ref($om), 'File::OM::ANVL', 'made a "new File::OM::ANVL" object';

is $om->elems('a', 'b', 'c', 'd'), "a: b\nc: d\n", 'elems for ANVL';

is $om->elems('a', 'b now is the time for all good men to come to the aid of the party and it is still time', 'c', 'd now is the time for all good men to come to the aid of the party and it is still time'),
  'a: b now is the time for all good men to come to the aid of the party
	and it is still time
c: d now is the time for all good men to come to the aid of the party
	and it is still time
',
	'bigger elems for ANVL';

$om = File::OM::ANVL->new();
is ref($om), 'File::OM::ANVL',
	'made a File::OM::ANVL object using subclass constructor';

$om = File::OM->new("xml");
is $om->elems('a', 'b now is the time for all good men to come to the aid of the party and it is still time', 'c', 'd now is the time for all good men to come to the aid of the party and it is still time'),
  '<a>b now is the time for all good men to come to the aid of the party
	and it is still time</a>
<c>d now is the time for all good men to come to the aid of the party
	and it is still time</c>
',
	'bigger elems for XML';

#$om = new File::OM::XML({outhandle => *STDERR});
#is $om->{outhandle}, *STDERR, '"new XML" object with options';

}
