# AWS Lambda Function: Start Minecraft EC2 Template

The golden master ami will stop the instance if no connections exist on the port for 15 minutes.

The image also contains a connection to elastic filesystem which holds all instance state.


## Lambda Policies

The lambda aws role has three policies attached and is passed into zappa to be attached to the lambda function.


## Brittleness

Currently the lambda stores instance id as an envvvar which expires, allowing more than 1 server to come up when the lambda loses its envvar. We need to store the instance id in a more permanent place e.g. ssm param.


## Zappa Roles

Zappa deployer default roles are pretty permissive. This needs reduced: https://github.com/Miserlou/Zappa#custom-aws-iam-roles-and-policies-for-deployment


## Custom Domain + Zappa

- https://romandc.com/zappa-django-guide/walk_domain/


## Server Status Checker

This is currently a shell script that sits in cron and tests every minute.

Crontab entry:  `*/1 * * * * ./detect_empty_server`


### counting connections

Would rather do this as a systemd process and just count connections with gnu stuff

- lsof method: https://www.instructables.com/id/Make-Your-Minecraft-Server-Tell-You-When-Players-a/
  - also has some good ideas about smtp messaging that might be nice.



### Old idea: write python service to talk to python server and then manage with systemd

https://github.com/Dinnerbone/mcstatus

This can also be used to report amount of time without a login if desired.  Then the EC2 instance can be shut down when idle for 30 minutes or something.


## Connection management

I would rather broker the connection with zappa 

so that zappa flips the server on if a minecraft connection comes through (or a connection on the mc port)

then zappa could keepalive until finally redirecting or proxying the connection

can we redirect the minecraft client from within zappa, if not can we proxy the connection

if proxy what is the lambda cost for say 144 hours of proxying?  any good ways to avoid shuttling all data thru proxy?

