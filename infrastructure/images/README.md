# Generating an AMI

Currently the AMI is built with packer and hardcoded into terraform.


## Future

The AMI should be generated from codesuite with packer then written to a SSM parameter where it is pulled for terraform.


## Requirements

- `brew install ansible packer`
