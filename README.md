# AWS Lambda Function: Start EC2 Instance


Also might have a function to stop the instance when it receives a signal... and maybe even poll for that signal? Would rather have the signal pushing go to this from the EC2 instance since the EC2 instance is running and the lamdba costs money to run.


## Hibernation

Instance hibernation will significantly speed up launch times and preserve existing game state.

Just set `Hibernate=True` in stop_instances.



## Zappa Roles

Zappa default roles are pretty permissive. This needs reduced: https://github.com/Miserlou/Zappa#custom-aws-iam-roles-and-policies-for-deployment

