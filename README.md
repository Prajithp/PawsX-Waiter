# NAME

PawsX::Waiter - A Waiter library for Paws

# SYNOPSIS

   use Paws;
   use PawsX::Waiter;

   my $client = Paws->new(
      config => {
          region      => 'ap-south-1'
       }
    );

    my $service = $client->service('ELB');

    # Apply waiter role to Paws class
    PawsX::Waiter->meta->apply($service);
    my $response = $service->RegisterInstancesWithLoadBalancer(
        LoadBalancerName => 'test-elb',
        Instances        => [ { InstanceId => 'i-0xxxxx'  } ]
    );

    my $waiter = $service->GetWaiter('InstanceInService');
    $waiter->wait(
        {
            LoadBalancerName => 'test-elb',
            Instances        => [ { InstanceId => 'i-0xxxxx' } ],
        }
    );
    

# DESCRIPTION

PawsX::Waiter is 

# LICENSE

Copyright (C) Prajith Ndz.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Prajith Ndz <prajithpalakkuda@gmail.com>
