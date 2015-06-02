#!perl -T

use Test::More;
eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;

# all_pod_coverage_ok();

my $trustme = { trustme => [
  qw/
      command
      head
      HyperLink
      initialize
      interior_sequence
      parse_from_filehandle
    /] };

pod_coverage_ok('Pod::Lualatex', $trustme);

done_testing();

