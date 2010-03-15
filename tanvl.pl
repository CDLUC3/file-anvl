#!/usr/bin/perl -w -Ilib

use File::ANVL;

my $x = anvl_elem("nam: now is the
time for all good
men to come
to the aid of the party again and again and again.");
print $x;

$x = anvl_elem("nam:
newline now is the
time for all good
men to come
to the aid of the party again and again and again.");
print $x;

$x = file2value("f2vtest"); print "|$x|\n";
$x = file2value("f2vtest", "trim"); print "|$x|\n";
$x = file2value("f2vtest", "raw"); print "|$x|\n";
$x = file2value("f2vtest", "untaint"); print "|$x|\n";

$x = file2value("f2vtest", "trim", 0); print "|$x|\n";
$x = file2value("f2vtest", "trim", 12); print "|$x|\n";
$x = file2value("f2vtest", "trim", 12000); print "|$x|\n";
