# -*- mode: cperl -*-

use strict;
use warnings;
use Test::More;

plan skip_all => 'RUN_LUALATEX=1 to run perldoc -o lualatex' unless $ENV{RUN_LUALATEX};

use_ok('Pod::Lualatex');

use Perl6::Slurp;

sub pod2latex {
  my ($pod, $lang) = @_;
  open my $perldoc, "-|", 'perldoc', '-u', $lang? ('-L', $lang) : (), $pod;
  open my $tex, ">", "texput.tex";
  my $parser = Pod::Lualatex->new();
  $parser->parse_from_filehandle($perldoc, $tex);
  close $perldoc;
  close $tex;
  open STDIN, '<', '/dev/null';
  system("lualatex texput.tex >/dev/null"); # for 1..2;
  if (-f 'texput.log') {
    my @log = slurp 'texput.log';
    my $err = grep { /Fatal error occurred/ } @log;
    ok !$err, join(' ', join('=', 'POD_LUALATEX', $ENV{POD_LUALATEX} // ''),
                   'perldoc', '-o', 'lualatex', $pod);
    return 0 if $err;
  }
  1;
}


use File::Basename;

chop(my $perl_pod = `perldoc -l perl`);
my $pod_dir = dirname $perl_pod;
my @perlpod = map { /(\w+)\.pod$/; $1 } glob "$pod_dir/perl*.pod";
@perlpod = grep !/delta/, @perlpod;

for (
  (map { [undef, $_, 't/empty.yml' ] } @perlpod),
  (map { ['ja', $_, 't/hyperlink.yml' ] } @perlpod),
 ) {
  my ($lang, $pod, $yml) = @$_;
  my $name = $pod;
  delete $ENV{PERLDOC};
  delete $ENV{POD_LUALATEX};
  if ($yml) {
    if (my ($opt) = ($yml =~ /([\w-]+).yml/, '')) {
      $ENV{POD_LUALATEX} = $yml;
      $name = "$pod-$opt";
    }
  }
  diag $name;
  unlink glob "texput.*";
  pod2latex($pod, $lang) && pod2latex($pod, $lang);
  system "cp texput.pdf $name.pdf";
}


done_testing();
