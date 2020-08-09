# Minecraft Server Terraform

Not all AWS resources are terraformed. 

The lambda and associated configuration is not terraformed.

Currently no supprting resources are terraformed.


## Supporting Resources

- EC2 Launch Template: "minecraft-immutable-minimal"
  - Launch Template
  - AMI: "minecraft-minimal-ami"
    - FUTURE: packer + ansible?
  - EFS: manually constructed & attached to AMI
    - FUTURE: data resource?
    - How to dynamically generate a fleet of minecraft installs?
      - Could use one EFS for whole fleet...
- Flask, Zappa Lambda, Zappa Infrastructure (generated cloudformation)


## Terraform Configuration

- workspace: default
- backend: https://github.com/robbintt/radiant-infra/tree/master/terraform/tf-backend-bootstrap
