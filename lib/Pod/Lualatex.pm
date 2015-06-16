package Pod::Lualatex;

use warnings;
use strict;

use version;
our $VERSION = qv('0.1.9');

use parent qw(Pod::LaTeX);
use YAML::Any qw/LoadFile/;
use Pod::ParseLink;
use HTML::Entities;
use URI::Encode qw(uri_encode uri_decode);
use URI::Escape qw(uri_escape);
use Encode;

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
      if ($section) {
        $section =~ s/^"(.*)"$/$1/;
        $section =~ s/^\s*(.*?)\s*$/$1/;
        $section =~ s/\s+/ /sg;
      }
      my ($man_name, $man_sect);
      if ($type eq 'man') {
        ($man_name = $name) =~ s/\((.+?)\)$//s;
        $man_sect = $1;
      }
      # L<name/section>     => $n/$s
      # L<name(m)>          => $n($m)
      # L<name(m)/section>  => $n($m)/$s
      # L</section>         => /$s or /$l (for '\hyperref[$l]{$i}')
      if (my $link = $self->HyperLink->{$type}) {
        my %x = ();
        $x{n} = $man_name || $name                           if $name;
        $x{m} = $man_sect                                    if $man_sect;
        $x{s} = (my $s = $section) =~ s/\s+/-/r              if $section;
        $x{i} = $inferred                                    if $inferred;
        $x{l} = $self->_create_label($section)               if $section;

        $x{$_} = $self->_replace_special_chars($x{$_})       for qw/i/;
        $x{$_} = $self->_replace_special_chars($self->uri($x{$_}))
                                                             for qw/m n s/;

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


sub uri {
  my ($self, $x) = @_;
  if ($x) {
    $x = uri_escape(uri_encode(uri_decode($x)), '~');
  }
  $x;
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

  my $index_command =
    qr/ \\ (?:index|label) (?&block)
        (?(DEFINE)
          (?<block> { (?&token)* } )
          (?<token> \\. | [^{}] | (?&block) )
        ) /x;

  $paragraph =~ s/ \s* $index_command //sxg;
  $self->SUPER::head($num, $paragraph, $parobj);
}


sub parse_from_filehandle {
  my $self = shift;

  my @opts = (ref $_[0] eq 'HASH') ? shift : ();
  my ($in_fh, $out_fh) = @_;
  open my $tmp_fh, ">:encoding(UTF-8)", \ my $tex;
  $self->SUPER::parse_from_filehandle(@opts, $in_fh, $tmp_fh);
  close $tmp_fh;

  # concatenate subsequent verbatim
  $tex =~ s/\\end{verbatim}\n\\begin{verbatim}//sg;

  print $out_fh $tex;
}


sub initialize {
  my $self = shift;
  my $c = $self->{_lualatex} || do {
    my $file = $ENV{POD_LUALATEX} // (glob '~/.pod-lualatex')[0];
    -r $file && LoadFile($file) // { };
  };
  if ($c) {
    $self->{$_} = $c->{$_} for keys %$c;
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
    url: '\href{$n}{$i}'
    man:
      - '\href{https://www.freebsd.org/cgi/man.cgi?query=$n($n)}{$i}'
      #- '\href{http://linux.die.net/man/$m/$n\#$s}{$i}'
      #- '\href{http://linux.die.net/man/$m/$n}{$i}'
    pod:
      - '\href{https://metacpan.org/module/$n\#$s}{$i}'
      - '\href{https://metacpan.org/module/$n}{$i}'
      - '\hyperref[$l]{$i}'

You can find some variables in the C<HyperLink:>. The C<$i>, C<$n>,
C<$s>, C<$l> are result of L<Pod::ParseLink>.

   $i: $inferred              $l: $section, s/\s+/-/g
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
