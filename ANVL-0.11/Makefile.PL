use 5.000000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    EXE_FILES         => [ 'nam' ],
    NAME              => 'ANVL',
    VERSION_FROM      => 'VERSION',    # finds $VERSION
    #VERSION           => '0.1',
    # to prevent other modules from being included
    PM			=> {'lib/File/ANVL.pm' => 'blib/lib/File/ANVL.pm'},
    PREREQ_PM         => {
	'Text::Wrap'		=> '0',
	'File::Glob'		=> '0',
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/File/ANVL.pm', # retrieve abstract from module
       AUTHOR         => 'John Kunze <jak@ucop.edu>') : ()),
);
