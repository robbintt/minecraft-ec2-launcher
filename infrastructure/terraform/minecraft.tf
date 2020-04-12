resource "aws_vpc" "minecraft_ec2_launcher" {
  tags       = merge(local.tf_global_tags, local.project_name_tag)
  cidr_block = "10.2.0.0/16"
}

data "aws_efs_file_system" "cincicraft" {
  file_system_id = "fs-dbe70e5a"
}

output "cincicraft_efs_dns_name" {
  value = data.aws_efs_file_system.cincicraft.dns_name
}
  
