locals {

  az = "us-east-1a"

}

resource "aws_vpc" "minecraft_ec2_launcher" {
  tags                 = merge(local.tf_global_tags, local.project_name_tag)
  cidr_block           = "10.2.0.0/16"
  enable_dns_hostnames = "true"
  enable_dns_support   = "true"
}

# imported, I think this was created automatically with the VPC...
# https://www.terraform.io/docs/providers/aws/r/route_table.html
# "Note that the default route, mapping the VPC's CIDR block to "local", is created implicitly and cannot be specified."
resource "aws_route_table" "minecraft_ec2_launcher" {
  tags   = merge(local.tf_global_tags, local.project_name_tag)
  vpc_id = aws_vpc.minecraft_ec2_launcher.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.minecraft_ec2_launcher.id
  }
}

resource "aws_subnet" "minecraft_subnet_e1a" {
  tags              = merge(local.tf_global_tags, local.project_name_tag)
  vpc_id            = aws_vpc.minecraft_ec2_launcher.id
  cidr_block        = "10.2.0.0/24"
  availability_zone = local.az
}

resource "aws_subnet" "minecraft_packer_subnet_e1a" {
  tags                    = merge(local.tf_global_tags, local.project_name_tag)
  vpc_id                  = aws_vpc.minecraft_ec2_launcher.id
  cidr_block              = "10.2.2.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "minecraft_ec2_launcher" {
  tags   = merge(local.tf_global_tags, local.project_name_tag)
  vpc_id = aws_vpc.minecraft_ec2_launcher.id
}

resource "aws_security_group" "minecraft_ec2_instance" {
  tags        = merge(local.tf_global_tags, local.project_name_tag)
  name        = "minecraft_ec2_instance"
  description = "rules for minecraft ec2 instance"
  vpc_id      = aws_vpc.minecraft_ec2_launcher.id

  ingress {
    description = "Minecraft Clients"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NFS over VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.minecraft_ec2_launcher.cidr_block]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # should be covered by default
  egress {
    description = "NFS over VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.minecraft_ec2_launcher.cidr_block]
  }

  # Created by aws, but removed by tf by default (security). Needs added manually.
  # this can probably be removed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_efs_file_system" "cincicraft" {
  file_system_id = "fs-dbe70e5a"
}

resource "aws_key_pair" "minecraft_ec2_key" {
  tags       = merge(local.tf_global_tags, local.project_name_tag)
  key_name   = "ec2-c5-minecraft-1"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCGZKb31GQFOR7sYzEvya5NBj1wPnrdkICmJyjJuKMW2RmzLdoJdPJgEG9GmM51qkGf0hJR8DXay6ThhIHy5cbn1OagUXRteav2gkXppSQ5g7bC2pN5EQDXRS13Hu4pXNtr6/m7c6f+17exaIc5OuwkkM6a4SpsAdy/H1/prbTN2nEtgrs13mFljjttdtoRTb9fuvO4MrdMqVbSODB3c9HmBw5+uqmlxS9j8qZ0C3aUFSk1uc4vwbD8Mwrsm41wzGzqZ0j/R9oct6b6zPh+7xDMGmrw7j+iegiOR/WXoxkVG64lalAEZnNriC2c3Lngj3BkmMrSh9qbFuf1Xj4DJPH3"
}

# WARNING: You must manually update the default_version. See "output" on run.
# nb: ec2 key pair can be specified but not generated, no available data resource.
resource "aws_launch_template" "minecraft_ec2_launcher" {
  tags                                 = merge(local.tf_global_tags, local.project_name_tag)
  name                                 = "minecraft_ec2_launcher"
  image_id                             = "ami-00f687b3f8812063a" # TODO: Replace with data resource if possible
  instance_type                        = "a1.xlarge"
  key_name                             = aws_key_pair.minecraft_ec2_key.key_name
  instance_initiated_shutdown_behavior = "terminate"
  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tf_global_tags, local.project_name_tag)
  }
  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.tf_global_tags, local.project_name_tag)
  }
  iam_instance_profile {
    arn = aws_iam_instance_profile.minecraft_sns_playerloginout_instance_profile.arn
  }
  placement {
    tenancy           = "default"
    availability_zone = local.az
  }
  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type             = "one-time"
      instance_interruption_behavior = "terminate"
      # TODO: experimental, how much more expensive is this? maybe 10%?
      # also, will we need to wait for a block?
      # results on c5.xlarge: InsufficientInstanceCapacity. I guess I would need to wait?
      # block_duration_minutes = 60
    }
  }
  monitoring {
    enabled = true
  }
  network_interfaces {
    description                 = "Generated by minecraft-ec2-launcher launch template."
    associate_public_ip_address = "true"
    delete_on_termination       = "true"
    security_groups             = [aws_security_group.minecraft_ec2_instance.id]
    subnet_id                   = aws_subnet.minecraft_subnet_e1a.id
  }
  ebs_optimized = true
}

# this on-demand insance needs dried out with the spot launcher
resource "aws_launch_template" "minecraft_ec2_launcher_ondemand" {
  tags                                 = merge(local.tf_global_tags, local.project_name_tag)
  name                                 = "minecraft_ec2_launcher_ondemand"
  image_id                             = "ami-00f687b3f8812063a" # TODO: Replace with data resource if possible
  instance_type                        = "a1.xlarge"
  key_name                             = aws_key_pair.minecraft_ec2_key.key_name
  instance_initiated_shutdown_behavior = "terminate"
  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tf_global_tags, local.project_name_tag)
  }
  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.tf_global_tags, local.project_name_tag)
  }
  iam_instance_profile {
    arn = aws_iam_instance_profile.minecraft_sns_playerloginout_instance_profile.arn
  }
  placement {
    tenancy           = "default"
    availability_zone = local.az
  }
  monitoring {
    enabled = true
  }
  network_interfaces {
    description                 = "Generated by minecraft-ec2-launcher launch template."
    associate_public_ip_address = "true"
    delete_on_termination       = "true"
    security_groups             = [aws_security_group.minecraft_ec2_instance.id]
    subnet_id                   = aws_subnet.minecraft_subnet_e1a.id
  }
  ebs_optimized = true
}

resource "aws_sns_topic" "minecraft_user_connection_events" {
  name = "minecraft_user_connection_events"
}

data "aws_iam_policy_document" "default_iam_role_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "minecraftlambda_iam_role_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "events.amazonaws.com", "ec2.amazonaws.com", "apigateway.amazonaws.com"]
    }
  }
}


data "aws_iam_policy_document" "gateway_iam_role_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "minecraft_sns_playerloginout" {
  name               = "minecraft_sns_playerloginout"
  assume_role_policy = data.aws_iam_policy_document.default_iam_role_assume_role_policy.json
}

resource "aws_iam_role" "gateway_logs_default_policy_role" {
  name               = "gateway_logs_default_policy"
  assume_role_policy = data.aws_iam_policy_document.gateway_iam_role_assume_role_policy.json
}

data "aws_iam_policy_document" "minecraft_sns_playerloginout" {
  statement {
    actions = [
      "sns:Publish",
    ]
    resources = [
      aws_sns_topic.minecraft_user_connection_events.arn,
    ]
  }
}

resource "aws_iam_policy" "minecraft_sns_playerloginout" {
  name        = "minecraft_sns_playerloginout"
  description = "Policy for role to publish to minecraft_user_connection_events SNS topic"
  policy      = data.aws_iam_policy_document.minecraft_sns_playerloginout.json
}

resource "aws_iam_role_policy_attachment" "minecraft_sns_playerloginout" {
  role       = aws_iam_role.minecraft_sns_playerloginout.name
  policy_arn = aws_iam_policy.minecraft_sns_playerloginout.arn
}

resource "aws_iam_role_policy_attachment" "gateway_logs_default_policy" {
  role       = aws_iam_role.gateway_logs_default_policy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_iam_instance_profile" "minecraft_sns_playerloginout_instance_profile" {
  name = "minecraft_sns_playerloginout_instance_profile"
  role = aws_iam_role.minecraft_sns_playerloginout.name
}

resource "aws_iam_role" "lambda_ec2_manager" {
  name               = "minecraft_lambda_ec2_manager"
  assume_role_policy = data.aws_iam_policy_document.minecraftlambda_iam_role_assume_role_policy.json
}

# this needs restricted, then attached to a iam group and set on the zappa lambda somehow (in zappa? manually?)
# each section needs broken out and resources restricted
# not sure if some describe goes in the launch template section
data "aws_iam_policy_document" "lambda_ec2_manager" {
  statement {
    actions = [
      "iam:PassRole",
    ]
    resources = [aws_iam_role.minecraft_sns_playerloginout.arn]
  }
  # i don't think GetLaunchTemplateData is used since it queries an instance for its launch template data...
  #statement {
  #  actions = [
  #      "ec2:GetLaunchTemplateData",
  #  ]
  #  resources = [ aws_launch_template.minecraft_ec2_launcher.arn, aws_launch_template.minecraft_ec2_launcher_ondemand.arn ]
  #}
  statement {
    actions = [
      "ec2:Describe*",
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "ec2:DeleteTags",
      "ec2:StartInstances",
      "ec2:CreateTags",
      "ec2:RunInstances",
      "ec2:StopInstances",
      "ec2:AssociateIamInstanceProfile",
      "ec2:ReplaceIamInstanceProfileAssociation"
    ]
    resources = ["*"]
  }
}

# TODO: make ssm parameter for ec2 instance id and restrict this to it
data "aws_iam_policy_document" "minecraft_lambda_ssm_parameter_manager" {
  statement {
    actions = [
      "ssm:PutParameter",
      "ssm:AddTagsToResource",
      "ssm:GetParameters",
      "ssm:GetParameter"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_ssm_manager" {
  name        = "minecraft_ec2_launcher_ssm_manager"
  description = "Policy for minecraft ec2 launcher lambda to manage ssm parameters."
  policy      = data.aws_iam_policy_document.minecraft_lambda_ssm_parameter_manager.json
}

resource "aws_iam_policy" "lambda_ec2_manager" {
  name        = "minecraft_ec2_launcher"
  description = "Policy for lambda to manage minecraft ec2 instances."
  policy      = data.aws_iam_policy_document.lambda_ec2_manager.json
}

resource "aws_iam_role_policy_attachment" "lambda_ssm_manager" {
  role       = aws_iam_role.lambda_ec2_manager.name
  policy_arn = aws_iam_policy.lambda_ssm_manager.arn
}

resource "aws_iam_role_policy_attachment" "lambda_ec2_manager" {
  role       = aws_iam_role.lambda_ec2_manager.name
  policy_arn = aws_iam_policy.lambda_ec2_manager.arn
}

resource "aws_iam_role_policy_attachment" "aws_managed_lambda_basic_execution_role" {
  role       = aws_iam_role.lambda_ec2_manager.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "aws_managed_xray_writeonly" {
  role       = aws_iam_role.lambda_ec2_manager.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

# TODO: add more restrictive policy based on: https://github.com/Miserlou/Zappa/issues/244
# the policy_arn attached here does not exist in IaC
resource "aws_iam_role_policy_attachment" "zappa_overpermissive_policy" {
  role       = aws_iam_role.lambda_ec2_manager.name
  policy_arn = "arn:aws:iam::705280753284:policy/zappa_overpermissive_policy"
}

output "command_to_update_launch_templates_from_awscli" {
  value = "aws ec2 modify-launch-template --launch-template-id \"${aws_launch_template.minecraft_ec2_launcher.id}\" --default-version \"${aws_launch_template.minecraft_ec2_launcher.latest_version}\" --region \"us-east-1\""
}
output "command_to_update_ondemand_launch_templates_from_awscli" {
  value = "aws ec2 modify-launch-template --launch-template-id \"${aws_launch_template.minecraft_ec2_launcher_ondemand.id}\" --default-version \"${aws_launch_template.minecraft_ec2_launcher_ondemand.latest_version}\" --region \"us-east-1\""
}
output "minecraft_subnet_e1a_id" {
  value = aws_subnet.minecraft_subnet_e1a.id
}
output "minecraft_user_connection_events_sns_arn" {
  value = aws_sns_topic.minecraft_user_connection_events.arn
}
