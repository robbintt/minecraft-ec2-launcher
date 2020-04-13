resource "aws_vpc" "minecraft_ec2_launcher" {
  tags       = merge(local.tf_global_tags, local.project_name_tag)
  cidr_block = "10.2.0.0/16"
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
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "minecraft_subnet_e1b" {
  tags              = merge(local.tf_global_tags, local.project_name_tag)
  vpc_id            = aws_vpc.minecraft_ec2_launcher.id
  cidr_block        = "10.2.1.0/24"
  availability_zone = "us-east-1b"
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

  egress {
    description = "NFS over VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.minecraft_ec2_launcher.cidr_block]
  }

  # Created by aws, but removed by tf by default (security). Needs added manually.
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

output "minecraft_subnet_e1a_id" {
  value = aws_subnet.minecraft_subnet_e1a.id
}

output "minecraft_subnet_e1b_id" {
  value = aws_subnet.minecraft_subnet_e1b.id
}

output "minecraft_zappa_sg" {
  value = aws_security_group.zappa_flask_app_minecraft_ec2_launcher.id
}
