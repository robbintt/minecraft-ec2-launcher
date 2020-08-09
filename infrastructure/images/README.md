# Generating an AMI

Currently the AMI is built with packer and hardcoded into terraform.

## Howto:

```
packer build packer.json
```

Put the new image ID into the launch templates.

## Future

The AMI should be generated from codesuite with packer then written to a SSM parameter where it is pulled for terraform.


## Requirements

- `brew install ansible packer`

- nb: packer aws subnet must be configured to auto-assign a public IP
  - this is done in this project
