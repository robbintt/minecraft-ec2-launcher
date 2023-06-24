data "aws_route53_zone" "ftl_cc" {
  name         = "ftl.cc"
  private_zone = false
}

resource "aws_acm_certificate" "minecraft_ftl_cc" {
  domain_name       = "minecraft.ftl.cc"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "minecraft_ftl_cc" {
  for_each = {
    for dvo in aws_acm_certificate.minecraft_ftl_cc.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.ftl_cc.zone_id
}

resource "aws_acm_certificate_validation" "minecraft_ftl_cc" {
  certificate_arn         = aws_acm_certificate.minecraft_ftl_cc.arn
  validation_record_fqdns = [for record in aws_route53_record.minecraft_ftl_cc : record.fqdn]
}

output "minecraft_aws_acm_certificate_arn" {
  value = aws_acm_certificate.minecraft_ftl_cc.arn
}
