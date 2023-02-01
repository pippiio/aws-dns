resource "aws_route53_zone" "this" {
  for_each = var.zones

  name = each.key
}
