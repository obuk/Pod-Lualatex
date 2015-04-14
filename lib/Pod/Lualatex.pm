package Pod::Lualatex;

use warnings;
use strict;

use version;
our $VERSION = qv('0.0.1');

use parent qw(Pod::LaTeX);

sub UserPreamble {
  my $self = shift;

  # Get the pod identification
  # This should really come from the '=head1 NAME' paragraph

  my $infile = $self->input_file;
  my $class = ref($self);
  my $date = gmtime(time);

  # Comment message to say where this came from
  my $comment = << "__TEX_COMMENT__";
%%  Latex generated from POD in document $infile
%%  Using the perl module $class
%%  Converted on $date
__TEX_COMMENT__

  # Write the preamble
  # If the caller has supplied one then we just use that

  my $preamble = '';

  # Write our own preamble

  # Code to initialise index making
  # Use an array so that we can prepend comment if required
  my @makeidx = (
    '\usepackage{makeidx}',
    '\makeindex',
   );

  unless ($self->MakeIndex) {
    foreach (@makeidx) {
      $_ = '%% ' . $_;
    }
  }
  my $makeindex = join("\n",@makeidx) . "\n";

  # Table of contents
  my $tableofcontents = '\tableofcontents';

  $tableofcontents = '%% ' . $tableofcontents
    unless $self->TableOfContents;

  # Roll our own
  $preamble = << "__TEX_HEADER__";
\\documentclass{ltjsarticle}
\\usepackage[T1]{fontenc}
\\usepackage{textcomp}

$comment

$makeindex

\\begin{document}

$tableofcontents

__TEX_HEADER__

  $preamble;
}


sub command {
  my $self = shift;
  my ($command, $paragraph, $line_num, $parobj) = @_;

  # return if we don't care
  return if $command eq 'encoding';

  $self->SUPER::command(@_);
}


1; # Magic true value required at end of module
__END__

=head1 NAME

Pod::Lualatex - [One line description of module's purpose here]


=head1 VERSION

This document describes Pod::Lualatex version 0.0.1


=head1 SYNOPSIS

    use Pod::Lualatex;


=head1 DESCRIPTION

=over

=item UserPreamble

=item command

=back


=head1 AUTHOR

KUBO Koichi  C<< <k@obuk.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2015, KUBO Koichi C<< <k@obuk.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
