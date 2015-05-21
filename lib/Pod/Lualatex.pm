package Pod::Lualatex;

use warnings;
use strict;

use version;
our $VERSION = qv('0.1.2');

use parent qw(Pod::LaTeX);
use YAML::Any qw/LoadFile/;

sub UserPreamble {
  my $self = shift;

  # Get the pod identification
  # This should really come from the '=head1 NAME' paragraph

  my $infile = $self->input_file;
  my $class = ref($self);
  my $date = gmtime(time);

  # Comment message to say where this came from
  my %x; $x{comment} = << "__TEX_COMMENT__";
%%  Latex generated from POD in document $infile
%%  Using the perl module $class
%%  Converted on $date
__TEX_COMMENT__

  # Make our own preamble

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
  $x{makeindex} = join("\n", @makeidx) . "\n";

  # Table of contents
  $x{tableofcontents} = '\tableofcontents';
  $x{tableofcontents} = '%% ' . $x{tableofcontents}
    unless $self->TableOfContents;

  my $preamble = $self->{preamble};

  # Roll our own
  $preamble //= << '__TEX_HEADER__';
\documentclass{ltjsarticle}
\usepackage[T1]{fontenc}
\usepackage{textcomp}

$comment

$makeindex

\begin{document}

$tableofcontents

__TEX_HEADER__

  $preamble =~ s/\$(\w+)/$x{$1}/g;
  $preamble;
}


sub command {
  my $self = shift;
  my ($command, $paragraph, $line_num, $parobj) = @_;

  if ($command eq 'encoding') {
    binmode $self->input_handle, ":encoding($paragraph)";
    binmode $self->output_handle, ":encoding(UTF-8)";
    return;
  }

  $self->SUPER::command(@_);
}


sub initialize {
  my $self = shift;
  my @config_file = ($ENV{POD_LUALATEX}, glob '~/.pod-lualatex');
  if (my ($file) = grep { $_ && -f $_ } @config_file) {
    if (my $config = LoadFile($file)) {
      $self->{$_} = $config->{$_} for keys %$config;
    }
  }
  $self->SUPER::initialize;
}


1; # Magic true value required at end of module
__END__

=head1 NAME

Pod::Lualatex - Convert Pod data to formatted lualatex


=head1 SYNOPSIS

  my $parser = Pod::Lualatex->new();
  $parser->parse_from_file('file.pod', 'file.tex');

or

  perldoc -o lualatex ...


=head1 DESCRIPTION

=over

=item UserPreamble

=item command

=item initialize

=back

=head1 CONFIGURATION AND ENVIRONMENT

=over

=item C<~/.pod-lualatex>

  preamble: |-
    \documentclass{ltjsarticle}
    \usepackage[T1]{fontenc}
    \usepackage{textcomp}
    
    %\usepackage[margin=2cm,nohead]{geometry}
    \usepackage{newtxtext,newtxmath}
    \usepackage{graphicx}
    \usepackage{fancybox}
    \usepackage{framed}
    
    \renewenvironment{verbatim}
    {\VerbatimEnvironment\begin{oframed}\begin{Verbatim}}
    {\end{Verbatim}\end{oframed}}
    
    $comment
    
    $makeindex
    
    \begin{document}
    
    $tableofcontents

=back


=head1 AUTHOR

KUBO Koichi  C<< <k@obuk.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2015, KUBO Koichi C<< <k@obuk.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
