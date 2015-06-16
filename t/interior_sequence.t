# -*- mode: cperl -*-

use strict;
use warnings;
use Test::More;
use YAML::Any qw/Load/;

use_ok('Pod::Lualatex');

my $parser = Pod::Lualatex->new(_lualatex => Load(<<'END'));
HyperLink:
  url: '\href{$n}{$i}'
  pod:
    - '\href{https://metacpan.org/module/$n\#$s}{$i}'
    - '\href{https://metacpan.org/module/$n}{$i}'
    - '\hyperref[$l]{$i}'
  man:
    - '\href{http://linux.die.net/man/$m/$n\#$s}{$i}'
    - '\href{http://linux.die.net/man/$m/$n}{$i}'
    - '\href{https://www.freebsd.org/cgi/man.cgi?query=$n}{$i}'
END

is $parser->interior_sequence('L', 'perl(1)/SYNOPSIS'),
  '\href{http://linux.die.net/man/1/perl\#SYNOPSIS}{SYNOPSIS in perl(1)}';

is $parser->interior_sequence('L', 'h2xs'),
  '\href{https://metacpan.org/module/h2xs}{h2xs}';

is $parser->interior_sequence('L', 'perldoc|http://perldoc.perl.org'),
  '\href{http://perldoc.perl.org}{perldoc}';

is $parser->interior_sequence('L', '/BUGS'),
  '\hyperref[BUGS]{BUGS}';

is $parser->interior_sequence(
  'L', 'http://www.cl.cam.ac.uk/~mgk25/unicode.html'),
  '\href{http://www.cl.cam.ac.uk/\%7Emgk25/unicode.html}'.
  '{http://www.cl.cam.ac.uk/\texttt{\~{}}mgk25/unicode.html}';

is $parser->interior_sequence(
  'L', 'http://www.cl.cam.ac.uk/%7Emgk25/unicode.html'),
  '\href{http://www.cl.cam.ac.uk/\%7Emgk25/unicode.html}'.
  '{http://www.cl.cam.ac.uk/\%7Emgk25/unicode.html}';

done_testing();
