# ref: https://www.terraform.io/docs/providers/aws/index.html
provider "aws" {
  region                  = "us-east-1"
  shared_credentials_file = "~/.aws/credentials"
}
