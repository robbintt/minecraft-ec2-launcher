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

This is currently a shell script that sits in cron and tests every minute.

Crontab entry:  `*/1 * * * * ./detect_empty_server.sh`


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

