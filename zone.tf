resource "aws_route53_zone" "this" {
  for_each = var.domains

  name = each.key
  tags = local.default_tags

  lifecycle {
    create_before_destroy = true
  }
}
