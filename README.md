# AWS Lambda Function: Start EC2 Instance


Also might have a function to stop the instance when it receives a signal... and maybe even poll for that signal? Would rather have the signal pushing go to this from the EC2 instance since the EC2 instance is running and the lamdba costs money to run.


## Brittleness

This assumes it's the only EC2 instance in the region, lol.

FUTURE: Use a `tag` or something to track the correct EC2 instance or it's simply not going to work.


## Hibernation

Instance hibernation will significantly speed up launch times and preserve existing game state.

Just set `Hibernate=True` in stop_instances.



## Zappa Roles

Zappa default roles are pretty permissive. This needs reduced: https://github.com/Miserlou/Zappa#custom-aws-iam-roles-and-policies-for-deployment


## Custom Domain + Zappa

- https://romandc.com/zappa-django-guide/walk_domain/


## Server Status Checker

Ideally not shut down if people are online or something.

https://github.com/Dinnerbone/mcstatus

This can also be used to report amount of time without a login if desired.  Then the EC2 instance can be shut down when idle for 30 minutes or something.
