resource "aws_route53_record" "this" {
  for_each = { for entry in flatten([
    for domain, zone in var.config : [
      for key, record in zone.records : {
        key    = key
        zone   = domain
        values = record.values
        type   = record.type
        ttl    = record.ttl
        } if !contains([
          "cloudfront",
          "redirect",
  ], lower(record.type))]]) : "${entry.zone}/${entry.type}/${entry.key}" => entry }

  zone_id         = aws_route53_zone.this[each.value.zone].zone_id
  name            = replace("${each.value.key}.${each.value.zone}", "/^[^\\w\\d]\\./", "")
  type            = upper(each.value.type)
  ttl             = each.value.ttl
  records         = each.value.values
  allow_overwrite = true
}

resource "aws_route53_record" "cloudfront" {
  for_each = { for entry in flatten([
    for domain, zone in var.config : [
      for key, record in zone.records : {
        key    = key
        zone   = domain
        values = record.values
  } if lower(record.type) == "cloudfront"]]) : "${entry.zone}/${entry.key}" => entry }

  zone_id         = aws_route53_zone.this[each.value.zone].zone_id
  name            = "${each.value.key}.${each.value.zone}"
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = one(each.value.values)
    zone_id                = "Z2FDTNDATAQYW2" # AWS Cloudfront zone id
    evaluate_target_health = true
  }
}
