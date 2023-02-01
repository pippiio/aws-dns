output "zones" {
  value = { for domain, zone in aws_route53_zone.this : domain => zone.name_servers }
}
