#!/usr/bin/perl

use feature 'say';

package PawsX::ClassBuilder;

use Moose;
use Path::Tiny;
use JSON::MaybeXS;

has api_struct => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->_load_json_file( $self->api_file );
    }
);

has waiters_file => (
    is       => 'ro',
    required => 1
);

has waiters_struct => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->_load_json_file( $self->waiters_file );
    }
);

has api_file => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $file = shift->waiters_file;
        $file =~ s/\/waiters-2\./\/service-2./;
        return $file;
    }
);

has service => (
    is      => 'ro',
    lazy    => 1,
    default => sub { $_[0]->api_struct->{metadata}->{endpointPrefix} }
);

has version => (
    is      => 'ro',
    lazy    => 1,
    default => sub { $_[0]->api_struct->{metadata}->{apiVersion} }
);

sub _load_json_file {
    my ( $self, $file ) = @_;
    return {} if ( not -e $file );

    my $f = path($file);
    return decode_json( $f->slurp );
}

package main;

use Path::Tiny;
use JSON::MaybeXS;

my $data_dir = $ARGV[0];
my $out_file = $ARGV[1];

my @files    = ();
my @services = path($data_dir)->children;
foreach my $service (@services) {
    next unless $service->is_dir;
    my @class_defs = grep { -f $_ } glob("$service/*/waiters-2.json");
    next if ( not @class_defs );
    @class_defs = sort @class_defs;

    my $lastest_version = pop @class_defs;
    push @files, $lastest_version;
}

my %json_struct = ();
foreach my $file (@files) {
    my $builder = PawsX::ClassBuilder->new( waiters_file => $file );
    my $service = $builder->service;
    my $version = $builder->version;
    $json_struct{$service}{$version} = $builder->waiters_struct->{'waiters'};
}

open my $fh, '>', $out_file or die $!;
print {$fh} encode_json( \%json_struct );
close $fh;

