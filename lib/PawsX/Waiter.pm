package PawsX::Waiter;

use strict;
use warnings;

use Moose::Role;
use JSON;
use File::Slurp qw(slurp);
use Path::Tiny;
use Data::Dumper;
use PawsX::Waiter::Client;

our $VERSION = "0.01";

sub GetWaiter {
    my ( $self, $waiter ) = @_;

    my $version     = $self->version;
    my $waiter_file = path(__FILE__)->parent->child('Waiter/waiters.json');

    my $service = lc $self->service;
    my $definition    = $waiter_file->slurp();
    my $waiter_struct = JSON->new->utf8(1)->decode($definition);

    if ( my $config = $waiter_struct->{$service}->{$version}->{$waiter} ) {
        return PawsX::Waiter::Client->new(
            client      => $self,
            delay       => $config->{'delay'},
            maxAttempts => $config->{'maxAttempts'},
            operation   => $config->{'operation'},
            acceptors   => $config->{'acceptors'},
        );
    }

    die "Invalid waiter: " . $waiter;
}

1;
__END__

=encoding utf-8

=head1 NAME

PawsX::Waiter - It's new $module

=head1 SYNOPSIS

    use PawsX::Waiter;

=head1 DESCRIPTION

PawsX::Waiter is ...

=head1 LICENSE

Copyright (C) Prajith Ndz.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Prajith Ndz E<lt>prajithpalakkuda@gmail.comE<gt>

=cut

