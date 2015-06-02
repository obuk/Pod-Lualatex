package Pod::Lualatex;

use warnings;
use strict;

use version;
our $VERSION = qv('0.1.6');

use parent qw(Pod::LaTeX);
use YAML::Any qw/LoadFile/;
use Pod::ParseLink;
use HTML::Entities;
use URI::Encode qw(uri_encode);

sub command {
  my $self = shift;
  my ($command, $paragraph, $line_num, $parobj) = @_;
  if ($command eq 'encoding') {
    binmode $self->input_handle, ":encoding($paragraph)";
  } else {
    $self->SUPER::command(@_);
  }
}


sub HyperLink {
   my $self = shift;
   if (@_) {
     $self->{HyperLink} = shift;
   }
   return $self->{HyperLink};
}


sub interior_sequence {
  my $self = shift;
  my ($seq_command, $seq_argument, $pod_seq) = @_;

  if ($seq_command eq 'L') {

    if (ref $self->HyperLink) {
      my $unescape = $self->_clean_latex_commands($seq_argument);
      $unescape =~ s/\\([{}_\$%&#])/$1/g;
      $unescape =~ s/\\([\^~]){}/$1/g;
      $unescape =~ s/\$\\backslash\$/\\/g;
      my ($text, $inferred, $name, $section, $type) = parselink($unescape);
      $inferred =~ s/"//sg if $inferred;
      my $label;
      if ($section) {
        $section =~ s/^"(.*)"$/$1/;
        $section =~ s/^\s*(.*?)\s*$/$1/;
        $section =~ s/\s+/ /sg;
        ($label = $section) =~ s/\s+/_/gs;
        $section =~ tr/ /-/;  # metacpan.org, perldoc.perl.org
      }
      if (my $link = $self->HyperLink->{$type}) {
        my %x = ();
        $x{n} = $name                 if $name;
        $x{s} = uri_encode($section)  if $section;
        $x{l} = $label                if $label;
        $x{i} = $self->_replace_special_chars($inferred) if $inferred;
        for (grep { $_ } ref $link? @$link : $link) {
          my $undef = 0;
          (my $link = $_) =~ s!\$(\w)!do {
            $undef++ unless defined $x{$1}; $x{$1} // '';
          }!eg;
          return $link unless $undef;
        }
      }

    }

  }

  return $self->SUPER::interior_sequence(@_);

}


sub _create_index {
  my $self = shift;
  # XXXXX: section{ \\index{ ... \n{2,} ... } }
  my $chunk = $self->SUPER::_create_index(@_);
  my @chunk = grep { $_ } split /\n/, $chunk;
  # XXXXX: \\index{ \\{ (\\})? }
  return join("\n", grep { !/^ ( \s* | \\{ (\\})? ) $/x } @chunk);
}


sub head {
  my $self = shift;
  my ($num, $paragraph, $parobj) = @_;

  my %x;
  my $block = qr/ (?&block)
                  (?(DEFINE)
                    (?<block> { (?&token)* } )
                    (?<token> \\. | [^{}] | (?&block) )
                  ) /x;

  while ($paragraph =~ s/ \s* (\\ (?:index|label) $block) //x) {
    (my $s = $1) =~ s/\s+/ /g; $x{$s}++;
  }

  my $pos = tell $self->output_handle;
  $self->SUPER::head($num, $paragraph, $parobj);
  my $bytes = tell($self->output_handle) - $pos;
  seek($self->output_handle, $pos, 0);
  read($self->output_handle, my $head, $bytes);

  while ($head =~ s/ \s* (\\ (?:index|label) $block) //x) {
    (my $s = $1) =~ s/\s+/ /g; $x{$s}++;
  }
  $head =~ /(\\\w+)\*?{(.*?)}$/s;
  my ($tag, $name) = ($1, $2);
  my $target = join("\n", $name, sort keys %x);

  seek($self->output_handle, $pos, 0);
  if ($self->HyperLink) {
    $self->_output("\\hypertarget{$name}{${tag}{$target}}\n");
  } else {
    $self->_output("${tag}{$target}\n");
  }
}


sub parse_from_filehandle {
  my $self = shift;

  my @opts = (ref $_[0] eq 'HASH') ? shift : ();
  my ($in_fh, $out_fh) = @_;
  open my $tmp_fh, "+>:encoding(UTF-8)", \ my $tex;
  $self->SUPER::parse_from_filehandle(@opts, $in_fh, $tmp_fh);
  close $tmp_fh;

  # concatenate subsequent verbatim
  $tex =~ s/\\end{verbatim}\n\\begin{verbatim}//sg;

  # XXXXX: POD_LUALATEX=t/hyperlink.yml perldoc -o lualatex perlintro
  $tex =~ s/(\\\w+){(\\href{[^}]+})({[^}]+})}/${2}{$1$3}/sg;

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
By default, C<Pod::Lualatex> will read a configuration from the
C<~/.pod-lualatex>, or the file specified in the C<POD_LUALATEX>
environment variable.

The format of the C<~/.pod-lualatex> is L<YAML>.

=over

=item *

replace the preamble:

  UserPreamble: |-
    \documentclass{ltjsarticle}
    \usepackage{luatexja}
    ...
    \begin{document}

=item *

use LE<lt>E<gt> as a hyperlink:

  UserPreamble: |-
    ...
    \usepackage[pdfencoding=auto]{hyperref}
  HyperLink:
    pod:
      - '\href{https://metacpan.org/module/$n#$s}{$i}'
      - '\href{https://metacpan.org/module/$n}{$i}'
      - '\hyperref[$l]{$i}'
    url: '\href{$n}{$i}'

You can find some variables in the C<HyperLink:>. The C<$i>, C<$n>,
C<$s>, C<$l> are result of L<Pod::ParseLink>.

   $i: $inferred              $l: $section, s/\s+/_/g
   $n: $name                  pod: url: $type
   $s: $section, uri_encode

=item *

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
