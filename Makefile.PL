use 5.014000;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME              => 'Gruntmaster::GUI',
	VERSION_FROM      => 'lib/Gruntmaster/GUI.pm',
	ABSTRACT_FROM     => 'lib/Gruntmaster/GUI.pm',
	AUTHOR            => 'Marius Gavrilescu <marius@ieval.ro>',
	EXE_FILES         => [qw/gruntmaster-gui/],
	MIN_PERL_VERSION  => '5.14.0',
	LICENSE           => 'perl',
	SIGN              => 1,
	PREREQ_PM         => {
		qw/Gruntmaster::Data 0
		   Sub::Name 0
		   Try::Tiny 0
		   Wx 0
		   Wx::Event 0/,
	},
	META_MERGE        => {
		dynamic_config => 0,
		resources      => {
			repository => 'https://git.ieval.ro/?p=gruntmaster-gui.git',
		}
	}
);
