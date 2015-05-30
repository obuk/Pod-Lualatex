# -*- mode: cperl -*-

use strict;
use warnings;
use Test::More;

# run: USE_LUALATEX=1 PERLDOC="-L ja" make test

plan skip_all => 'RUN_LUALATEX=1 to run perldoc -o lualatex' unless $ENV{RUN_LUALATEX};

use Perl6::Slurp;

sub pod2latex {
  my $pod = shift;
  open my $perldoc, "-|:encoding(UTF-8)", 'perldoc', '-o', 'lualatex', $pod;
  open STDIN, "<&", $perldoc;
  system("lualatex >/dev/null");
  if (-f 'texput.log') {
    my @log = slurp 'texput.log';
    my $err = grep { /Fatal error occurred/ } @log;
    ok !$err, join(' ', 'perldoc', '-o', 'lualatex', $pod);
  }
}

my @pod = qw/ perldsc perlsyn perlop perldebug perlref /;

for my $pod (@pod) {
  delete $ENV{POD_LUALATEX};
  diag $pod;
  unlink glob "texput.*";
  pod2latex($pod);
  system "cp texput.pdf $pod.pdf";
}


my @yml = glob "t/*.yml";

for my $yml (@yml) {
  my $pod = 'perlintro';
  $ENV{POD_LUALATEX} = $yml;
  my ($cf) = $yml =~ /([\w-]+).yml/;
  my $name = "$pod-$cf";
  diag $name;
  unlink glob "texput.*";
  pod2latex($pod);
  pod2latex($pod);
  system "cp texput.pdf $name.pdf";
}


done_testing();
