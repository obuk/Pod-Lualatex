# -*- mode: cperl -*-

use strict;
use warnings;
use Test::More;

# run: USE_LUALATEX=1 PERLDOC="-L ja" make test

plan skip_all => 'set RUN_LUALATEX=1 to test all' unless $ENV{RUN_LUALATEX};

use Perl6::Slurp;

my @pod =
  qw/
      perl perlintro perlrun perlbook perlcommunity

      perlreftut perldsc perllol perlrequick
      perlretut perlboot perlootut perltoot perltooc perlbot
      perlstyle perlcheat perltrap perldebtut
      perlopentut perlpacktut perlthrtut
      perlxstut perlunitut perlpragma

      perlsyn perldata perlsub perlop
      perlfunc perlpod perlpodspec perlpodstyle perldiag
      perllexwarn perldebug perlvar perlre perlrecharclass perlrebackslash
      perlreref perlref perlform perlobj perltie
      perldbmfilter perlipc perlfork perlnumber perlperf
      perlport perllocale perluniintro perlunicode perluniprops
      perlebcdic perlsec perlmod perlmodlib
      perlmodstyle perlmodinstall perlnewmod
      perlglossary perlexperiment perldtrace CORE

      perlembed perldebguts perlxs perlxstut perlxstypemap
      perlinterp perlsource perlrepository
      perlclib perlguts perlcall perlapi perlintern perlmroapi
      perliol perlapio perlhack perlhacktut perlhacktips
      perlreguts perlreapi perlpolicy

      perlartistic perlgpl
    /;

for my $pod (@pod) {
  open my $perldoc, "-|:encoding(UTF-8)", 'perldoc', '-o', 'lualatex', $pod;
  open STDIN, "<&", $perldoc;
  unlink glob "texput.*";
  system "lualatex";
  diag $pod;
  if (-f 'texput.log') {
    my @log = slurp 'texput.log';
    my $err = grep { /Fatal error occurred/ } @log;
    ok !$err;
  }
}

done_testing();
