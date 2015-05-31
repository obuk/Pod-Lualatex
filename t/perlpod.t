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
    ok !$err, join(' ', join('=', 'POD_LUALATEX', $ENV{POD_LUALATEX} // ''),
                   'perldoc', '-o', 'lualatex', $pod);
  }
}


for (
  (map { [$_, undef ] } qw/ perldsc perlsyn perlop perldebug perlref /),
  (map { ['perlintro', $_ ] } glob "t/*.yml"),
  # [qw(perlvar t/hyperlink.yml)]
 ) {
  my ($pod, $yml) = @$_;
  my $name = $pod;
  delete $ENV{POD_LUALATEX};
  if ($yml) {
    if (my ($opt) = ($yml =~ /([\w-]+).yml/, '')) {
      $ENV{POD_LUALATEX} = $yml;
      $name = "$pod-$opt";
    }
  }
  diag $name;
  unlink glob "texput.*";
  pod2latex($pod);
  pod2latex($pod);
  system "cp texput.pdf $name.pdf";
}


done_testing();
