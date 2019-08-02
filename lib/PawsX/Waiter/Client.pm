package PawsX::Waiter::Client;

use v5.20;
use Moose;

use feature qw(postderef say);
no warnings qw(experimental::postderef);

use Jmespath;
use Data::Structure::Util qw(unbless);
use Try::Tiny;

use PawsX::Waiter::Exception;

has client => (
    is       => 'ro',
    required => 1,
    weak_ref => 1,
);

has delay => (
    is       => 'rw',
    isa      => 'Int',
    required => 1,
);

has maxAttempts => (
    is       => 'rw',
    isa      => 'Int',
    required => 1,
);

has operation => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has acceptors => (
    is       => 'ro',
    isa      => 'ArrayRef[HashRef]',
    required => 1,
);

has 'beforeWait' => (
    traits    => ['Code'],
    is        => 'rw',
    isa       => 'CodeRef',
    predicate => 'has_beforeWait',
    handles   => {
        _beforeWait => 'execute_method',
    },
);

sub operation_request {
    my ( $self, $options ) = @_;

    my $func     = $self->operation;
    my $response = {};

    try {
        $response = $self->client->$func( $options->%* );
    }
    catch {
        my $error = $_;
        if ( blessed($error) and $error->isa('Paws::Exception') ) {
            $response = {
                code        => $error->code,
                request_id  => $error->request_id,
                http_status => $error->http_status,
                message     => $error->message,
            };
        }
        else {
            PawsX::Waiter::Exception->throw(
                name          => $self->operation,
                reason        => $error,
                last_response => $response,
            );
        }
    };
    return blessed($response) ? unbless($response) : $response;
}

sub wait {
    my ( $self, $options ) = @_;

    my $current_state = 'waiting';
    my $num_attempts  = 0;

    while (1) {
   
        my $response = $self->operation_request($options);
        $num_attempts++;
      
      ACCEPTOR:
        foreach my $acceptor ( $self->acceptors->@* ) {
            if ( my $status = $self->matcher( $acceptor, $response ) ) {
                $current_state = $acceptor->{'state'};
                last ACCEPTOR;
            }
        }

        if ( $current_state eq 'success' ) { return; }
        if ( $current_state eq 'failure' ) {
            PawsX::Waiter::Exception->throw(
                message       => 'Waiter encountered a terminal failure state',
                last_response => $response,
            );
        }
        if ( $num_attempts >= $self->maxAttempts ) {
            PawsX::Waiter::Exception::TimeOut->throw(
                message       => 'Max attempts exceeded',
                last_response => $response,
            );
        }

        $self->_beforeWait($num_attempts, $response) if $self->has_beforeWait;

        sleep( $self->delay );
    }
}

sub matcher {
    my ( $self, $acceptor, $response ) = @_;

    my $func = "match_" . $acceptor->{'matcher'};

    return $self->$func( $acceptor, $response );
}

sub match_path {
    my ( $self, $acceptor, $response ) = @_;

    if ( 'HASH' eq ref $response ) {
        my $ret =
          ( Jmespath->search( $acceptor->{'argument'}, $response ) eq
              $acceptor->{'expected'} ) ? 1 : 0;
        return $ret;
    }
    else {
        return 0;
    }
}

sub match_error {
    my ( $self, $acceptor, $response ) = @_;
    if ( 'HASH' eq ref $response && exists $response->{'code'} ) {
        my $ret =
          ( $response->{'code'} eq $acceptor->{'expected'} ) ? 1 : 0;
        return $ret;
    }
    else {
        return 0;
    }
}

sub match_pathAll {
    my ( $self, $acceptor, $response ) = @_;

    my $expression = Jmespath->compile( $acceptor->{'argument'} );
    my $result     = $expression->search($response);

    unless ( ref $result && 'ARRAY' eq ref $result
        and length $result >= 1 )
    {
        return 0;
    }

    for my $element ( $result->@* ) {
        return 0 unless $element eq $acceptor->{'expected'};
    }

    return 1;
}

sub match_pathAny {
    my ( $self, $acceptor, $response ) = @_;

    my $expression = Jmespath->compile( $acceptor->{'argument'} );
    my $result     = $expression->search($response);

    unless ( ref $result && 'ARRAY' eq ref $result
        and length $result >= 1 )
    {
        return 0;
    }

    for my $element ( $result->@* ) {
        return 1 if $element eq $acceptor->{'expected'};
    }

    return 0;
}

sub match_status {
    my ( $self, $acceptor, $response ) = @_;
    return $response->{'http_status'} == $acceptor->{'expected'};
}

1;
