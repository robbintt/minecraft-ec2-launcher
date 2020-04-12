locals {
  # update this per terraform project
  project_name = "minecraft-ec2-launcher"

  # this should be a module or something
  tf_global_tags = { "IaC" : "Terraform" }
}

# Backend bootstrapped in: https://github.com/robbintt/radiant-infra.git
# Update the key for the project
terraform {
  backend "s3" {
    bucket         = "terraform-backend-27aef5ec-0ff5-454f-82b4-23d3162f03a5"
    dynamodb_table = "terraform-backend-27aef5ec-0ff5-454f-82b4-23d3162f03a5-state-lock"
    key            = "minecraft-ec2-launcher.tfstate"
    region         = "us-east-1"
  }
}

