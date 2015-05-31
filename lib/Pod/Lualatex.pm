package Pod::Lualatex;

use warnings;
use strict;

use version;
our $VERSION = qv('0.1.6');

use parent qw(Pod::LaTeX);
use YAML::Any qw/LoadFile/;

use Pod::ParseLink;
use HTML::Entities;
use URI::Encode qw(uri_encode uri_decode);

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Terse = 1;

sub command {
  my $self = shift;
  my ($command, $paragraph, $line_num, $parobj) = @_;
  if ($command eq 'encoding') {
    binmode $self->input_handle, ":encoding($paragraph)";
  } else {
    $self->SUPER::command(@_);
  }
}


sub interior_sequence {
  my $self = shift;
  my ($seq_command, $seq_argument, $pod_seq) = @_;

  if ($seq_command eq 'X') {
    # XXXXX: \index{ \{ } X<{>
    return '' if $seq_argument =~ /{/;

  } elsif ($seq_command eq 'L') {

    if ($self->{HyperLink}) {
      (my $unescape = $seq_argument) =~ s/\\([{}_\$%&#])/$1/g;
      $unescape =~ s/\\([^~]){}/$1/g;
      $unescape =~ s/\$\\backslash\$/\\/g;
      my ($text, $inferred, $page, $section, $type) = parselink($unescape);
      $inferred =~ s/"//sg if $inferred;
      $self->_output("% HyperLink: L<$unescape>\n");
      (my $debug = Dumper(
        { text => $text, inferred => $inferred, page => $page,
          section => $section, type => $type, })) =~ s/^/% /gm;
      $self->_output("$debug\n");
      my $_section;
      if ($section) {
        $section =~ s/^"(.*)"$/$1/;
        $section =~ s/^\s*(.*?)\s*$/$1/;
        $section =~ s/\s+/ /sg;
        $_section = $section;
        $section =~ tr/ /-/;  # metacpan.org, perldoc.perl.org
      }
      if (my $link = $self->{HyperLink}{$type}) {
        my %x = ();
        $x{page    } = $page                 if $page;
        $x{section } = uri_encode($section)  if $section;
        $x{_section} = $self->_replace_special_chars($_section) if $_section;
        $x{inferred} = $self->_replace_special_chars($inferred) if $inferred;
        for (grep { $_ } ref $link? @$link : $link) {
          my $undef = 0;
          (my $link = $_) =~ s!\$(\w+)!do {
            $undef++ unless defined $x{$1}; $x{$1} // '';
          }!eg;
          # $self->_output("% HyperLink: L<$unescape> => $link ($undef)\n");
          return $link unless $undef;
        }
      }

    }

  }

  return $self->SUPER::interior_sequence(@_);

}


sub _create_index {
  my $self = shift;
  my ($paragraph) = @_;

  # XXXXX: section{ \index{ ... \n ... } }
  my $index = $self->SUPER::_create_index(@_);
  my @index = grep { $_ } split /\n/, $index;
  s/^\s*(.*?)\s*$/$1/ for @index;
  if ($self->{HyperLink}) {
    $self->_output("\\hypertarget{$_}{}\n") for @index;
  }
  return join("\n", @index);
}


sub head {
  my $self = shift;
  my $pos = tell $self->output_handle;
  $self->SUPER::head(@_);
  my $cur = tell $self->output_handle;
  seek($self->output_handle, $pos, 0);
  read $self->output_handle, my $code, $cur - $pos;
  my @code = grep { $_ } split /\n/, $code;
  s/^\s*(.*?)\s*$/$1/ for @code;
  seek($self->output_handle, $pos, 0);
  $self->_output("$_\n") for @code;
}


sub parse_from_filehandle {
  my $self = shift;

  my @opts = (ref $_[0] eq 'HASH') ? shift : ();
  my ($in_fh, $out_fh) = @_;
  open my $tmp_fh, "+>:encoding(UTF-8)", \ my $tex;
  $self->SUPER::parse_from_filehandle(@opts, $in_fh, $tmp_fh);
  close $tmp_fh;

  my $header = <<"__TEX_HEADER__";
\\documentclass{ltjsarticle}
\\usepackage{luatexja}
__TEX_HEADER__

  # replace header
  $tex =~ s/^\\document\w+{article}(.*?)(\n%%\s+Latex\s+generated)/$header$2/s;

  # concatenate subsequent verbatim
  $tex =~ s/\\end{verbatim}\n\\begin{verbatim}//sg;

  print $out_fh $tex;
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


=head1 DESCRIPTION

C<Pod::Lualatex> is a derived class from L<Pod::LaTeX>.
This module rewrites the header lines of the C<Pod::LaTeX> outputs
before C<%% Latex generated ...>. The output is as follows:

  \documentclass{ltjsarticle}
  \usepackage{luatexja}
  
  %%  Latex generated ...


=head1 CONFIGURATION AND ENVIRONMENT

By default, C<Pod::Lualatex> will read a configuration from the
C<~/.pod-lualatex>, or the file specified in the C<POD_LUALATEX>
environment variable.

=over

=item C<~/.pod-lualatex>

The format is L<YAML>.

  UserPreamble: |-
    \documentclass{ltjsarticle}
    \usepackage{luatexja}
    ...
    \begin{document}

for example, you need TOC:

  TableOfContents: 1
  LevelNoNum: 3
  UserPreamble: |-
    ...
    \usepackage{makeidx}
    \makeindex
    \begin{document}
    \tableofcontents
    %\newpage

surround the verbatim:

  UserPreamble: |-
    ...
    \usepackage[framemethod=tikz]{mdframed}
    \newrobustcmd*{\myframed}[2][]{%
      \BeforeBeginEnvironment{#2}{\medskip\begin{mdframed}[#1]\medskip}%
      \AfterEndEnvironment{#2}{\medskip\end{mdframed}}%
    }
    \myframed[linewidth=1pt,roundcorner=10pt]{verbatim}


=back

=head1 AUTHOR

KUBO Koichi  C<< <k@obuk.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2015, KUBO Koichi C<< <k@obuk.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
