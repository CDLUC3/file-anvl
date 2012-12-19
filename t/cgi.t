use 5.006;
use Test::More qw( no_plan );

# xxx To do: make test sets more comprehensive and systemmatic

use strict;
use warnings;

my $script = "anvl";		# script we're testing

# as of 2011.06.29  flvl() from File::Value
#### start boilerplate for script name and temporary directory support

use Config;
$ENV{SHELL} = "/bin/sh";
my $td = "td_$script";		# temporary test directory named for script
# Depending on circs, use blib, but prepare to use lib as fallback.
my $blib = (-e "blib" || -e "../blib" ?	"-Mblib" : "-Ilib");
my $bin = ($blib eq "-Mblib" ?		# path to testable script
	"blib/script/" : "") . $script;
my $perl = $Config{perlpath};		# perl used in testing
my $cmd = "2>&1 $perl $blib " .		# command to run, capturing stderr
	(-e $bin ? $bin : "../$bin") . " ";	# exit status in $? >> 8

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

use File::Value ':all';

#### end boilerplate

use CGI::Head;
use File::OM;

{
remake_td();
my ($cgih, $om, $x, $y);

$cgih = CGI::Head->new;
$x = $cgih->take;
# note: we can't count on order of output, so test headers individually
unlike $x, qr/^\n/, "doesn't start with a newline";

like $x, qr{Content-Type: text/plain\n},
	'CGI header contains default content type';

like $x, qr{Status: 200 OK\n},
	'CGI header contains default status';

$x = $cgih->take;
is $x, '',
	'subsequent "take" is empty';

$cgih->setfuse;
$cgih->add( { Foo => 'Bar' } );
$x = $cgih->take;
unlike $x, qr/^\n/, "doesn't start with a newline";
$y = (
	$x =~ qr{Content-Type: text/plain\n} &&
	$x =~ qr{Status: 200 OK\n} && $x =~ qr{Foo: Bar\n} );
is $y, 1,
	'but "take" comes back after "setfuse"';

$om = File::OM->new("ANVL", {
	cgih => $cgih,
} );
$x = $om->elem('ab', 'cd');
unlike $x, qr/^\n/, "doesn't start with a newline";
like $x, qr{^ab: cd\n$},
	"block previously fired in another content still won't fire";

$om = File::OM->new("ANVL", {
	cgih => CGI::Head->new,
} );
$x = $om->elem('ab', 'cd');
unlike $x, qr/^\n/, "doesn't start with a newline";
like $x, qr{Content-Type: text/plain\n.*ab: cd\n$}s,
	'ANVL CGI mode with default content type';

like $x, qr{Status: 200 OK\n},
	'ANVL CGI mode with default status';

is $om->elem('ef', 'gh'),
	"ef: gh\n",
	'ANVL CGI mode puts out headers only the first time';


$om = File::OM->new("ANVL", {
	cgih => CGI::Head->new,
} );
$om->{cgih}->add( { Status => '401 unauthorized' } );
$x = $om->elem('ab', 'cd');
unlike $x, qr/^\n/, "doesn't start with a newline";
like $x, qr{Status: 401 unauthorized\n.*\nab: cd\n}s,
	'ANVL CGI mode with updated status';

$cgih = CGI::Head->new( {
		'Location' => 'http://foo.example.com/bar',
		'Content-Type' => 'application/json',
		'Status' => '300 redirect',
	} );
$om = File::OM->new("JSON", { cgih => $cgih } );
$x = $om->elem('ab', 'cd');
unlike $x, qr/^\n/, "doesn't start with a newline";
like $x,
	qr|Content-Type: application/json\n.*\n\n\[\n.*{\n.*"ab|s,
	'JSON CGI mode with user-defined content type';

like $x,
	qr|Status: 300 redirect\n|s,
	'JSON CGI mode with user-defined status';

like $x,
	qr|Location: http://foo.example.com/bar\n|,
	'JSON CGI mode with user-defined but standard header';

$om = File::OM->new("Plain", {
	cgih => CGI::Head->new( {
		'Foo' => 'Bar',
		'Zaf' => 'Faz',
		'Content-Type' => 'text/plane',
	} ),
} );
$x = $om->elem('ab', 'cd'),
unlike $x, qr/^\n/, "doesn't start with a newline";
like $x,
	qr|Content-Type: text/plane\n.*\n\ncd\n|s,
	'Plain CGI mode with alternative content type name';

unlike $x, qr|Status:|,
	'Plain CGI mode with header block and no status';

like $x, qr{(?:Foo: Bar\n.*Zaf: Faz\n|Zaf: Faz\n.*Foo: Bar)}s,
	'Plain CGI mode with alternative user-defined headers';

$om = File::OM->new("Turtle", { cgih => CGI::Head->new } );
$x = $om->elem('ab', 'cd');
unlike $x, qr/^\n/, "doesn't start with a newline";
like $x,
	qr|Status: 200 OK\nContent-Type: text/plain\n\n\@prefix erc:|,
	'Turtle CGI mode';

# XXX maybe the content_type should be auto-set from known OM format type?
$om = File::OM->new("XML", {
	cgih => CGI::Head->new( { 'Content-Type' => 'application/xml' } ),
} );
$om->{cgih}->add( { Status => '403 forbidden' } );
$x = $om->elem('ab', 'cd');
unlike $x, qr/^\n/, "doesn't start with a newline";
like $x,
	qr|Status: 403 forbidden\n.*\n\n<recs|s,
	'XML CGI mode';

$om = File::OM->new("XML", {
	cgih => CGI::Head->new( { 'Content-Type' => 'application/xml' } ),
} );
$x = $om->DESTROY();
unlike $x, qr/^\n/, "doesn't start with a newline";
like $x,
	qr|^Content-Type: ap.*/xml\n\n$|,
	'CGI mode with no output still outputs headers on stream close';

# xxxxx why no PSV and CSV tests?

remove_td();
}
