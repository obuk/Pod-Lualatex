use inc::Module::Install;
name 'Pod-Lualatex';
all_from 'lib/Pod/Lualatex.pm';
license 'perl';
cpanfile;
#requires_external_bin 'lualatex';
WriteAll;
