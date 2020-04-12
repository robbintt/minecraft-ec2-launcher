

data "aws_efs_file_system" "cincicraft" {
  file_system_id = "fs-dbe70e5a"
}

output "cincicraft_efs_dns_name" {
  value = data.aws_efs_file_system.cincicraft.dns_name
}
  
