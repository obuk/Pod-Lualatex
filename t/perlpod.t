# -*- mode: cperl -*-

use strict;
use warnings;
use Test::More;

# run: USE_LUALATEX=1 PERLDOC="-L ja" make test

plan skip_all => 'RUN_LUALATEX=1 to run lualatex' unless $ENV{RUN_LUALATEX};

use Perl6::Slurp;

my @pod = qw/ perldsc perlsyn perlop perldebug perlref /;

for my $pod (@pod) {
  diag $pod;
  unlink glob "texput.*";
  open my $perldoc, "-|:encoding(UTF-8)", 'perldoc', '-o', 'lualatex', $pod;
  open STDIN, "<&", $perldoc;
  system("lualatex >/dev/null");
  if (-f 'texput.log') {
    my @log = slurp 'texput.log';
    my $err = grep { /Fatal error occurred/ } @log;
    ok !$err, join(' ', 'perldoc', '-o', 'lualatex', $pod);
  }
}

done_testing();
