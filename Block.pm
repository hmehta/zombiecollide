#!/usr/bin/perl

package Block;

use strict;
use warnings;

our $VERSION = 0.1;
our $AUTOLOAD;

sub new {
    my ($class, %opts) = @_;
    my $self = bless {}, $class;
    $self->{x}   = $opts{x}   // 0;
    $self->{y}   = $opts{y}   // 0;
    $self->{w}   = $opts{w}   // 0;
    $self->{h}   = $opts{h}   // 0;
    $self->{v_x} = $opts{v_x} // 0;
    $self->{v_y} = $opts{v_y} // 0;
    return $self;
}

sub AUTOLOAD {
    my ($self) = @_;
    (my $c = $AUTOLOAD) =~ s/^.*:://;
    return if ($c eq "DESTROY");
    return $self->{$c} if ($self->{$c});
}

1;

__END__

=head1 NAME

Block - 

=head1 VERSION

  Version 0.1

=head1 SYNOPSIS

  my $Block = Block->new(

  );

=head1 DESCRIPTION



=head1 AUTHOR

Heikki MehtE<195>nen, C<< <heikki@mehtanen.fi> >>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Heikki MehtE<195>nen, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

