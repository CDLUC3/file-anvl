use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'File::ANVL',
    AUTHOR              => 'John A. Kunze <jak@ucop.edu>',
    VERSION_FROM        => 'VERSION',
    ABSTRACT_FROM       => 'lib/File/ANVL.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'Apache2')
      : ()),
    PM			=> {
	'lib/File/ANVL.pm'	=> 'blib/lib/File/ANVL.pm',
    },
    PL_FILES            => {},
    PREREQ_PM => {
	'Text::Wrap'	=> 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'File-ANVL-*' },
);
