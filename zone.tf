resource "aws_route53_zone" "this" {
  for_each = var.config

  name = each.key

  lifecycle {
    create_before_destroy = true
  }
}
