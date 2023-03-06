output "zones" {
  value = { for domain, zone in aws_route53_zone.this : domain => {
    name_servers = zone.name_servers
    dnssec = {
      key_tag                = aws_route53_key_signing_key.dnssec[domain].key_tag
      digest                 = aws_route53_key_signing_key.dnssec[domain].digest_value
      digest_type            = aws_route53_key_signing_key.dnssec[domain].digest_algorithm_type
      signing_algorithm_type = aws_route53_key_signing_key.dnssec[domain].signing_algorithm_type
    }
  } }
}
