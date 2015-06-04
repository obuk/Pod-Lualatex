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
    - '\href{https://metacpan.org/module/$n#$s}{$i}'
    - '\href{https://metacpan.org/module/$n}{$i}'
    - '\hyperref[$l]{$i}'
  man:
    - '\href{http://linux.die.net/man/$m/$n#$s}{$i}'
    - '\href{http://linux.die.net/man/$m/$n}{$i}'
    - '\href{https://www.freebsd.org/cgi/man.cgi?query=$n}{$i}'
END

open my $tex_fh, "+>", \my $tex;
$parser->parse_from_filehandle(\*DATA, $tex_fh);

my @href = $tex =~ /(\\href{[^}]+}(?:{[^}]+})?)/gs;

my @href_expected =(
  '\href{http://linux.die.net/man/1/perl#SYNOPSIS}{SYNOPSIS in perl(1)}',
  '\href{https://metacpan.org/module/h2xs}{h2xs}',
  '\href{http://perldoc.perl.org}{perldoc}',
 );

is_deeply [@href], [@href_expected] or diag explain [@href];

done_testing();

__DATA__

=pod

L<perl(1)/SYNOPSIS>
L<h2xs>
L<perldoc|http://perldoc.perl.org>

=cut
