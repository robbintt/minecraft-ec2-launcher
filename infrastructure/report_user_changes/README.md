# Setup

The whole repo is cloned into efs and the virtualenv python is called by hand in the ec2-user crontab.

## Steps

Cron is set up via packer, we just need a virtualenv in efs at the moment. This can be done in packer later.

1. `virtualenv env -p python3`: Create a virtualenv `env` in the local directory
