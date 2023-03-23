resource "aws_route53_record" "this" {
  for_each = { for entry in flatten([
    for domain, zone in var.domains : [
      for key, record in zone.records : {
        key    = key
        zone   = domain
        values = record.values
        type   = record.type
        ttl    = record.ttl
        } if !contains([
          "cloudfront",
          "redirect",
          "txt",
  ], lower(record.type))]]) : "${entry.zone}/${entry.type}/${entry.key}" => entry }

  zone_id         = aws_route53_zone.this[each.value.zone].zone_id
  name            = replace("${each.value.key}.${each.value.zone}", "/^[!@#$%&]\\./", "")
  type            = upper(each.value.type)
  ttl             = each.value.ttl
  records         = each.value.values
  allow_overwrite = false
}

resource "aws_route53_record" "cloudfront" {
  for_each = { for entry in flatten([
    for domain, zone in var.domains : [
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

resource "aws_route53_record" "txt" {
  for_each = { for entry in flatten([
    for domain, records in local.txt : [
      for name, record in records : {
        domain = domain
        name   = name
        ttl    = record.ttl
        values = record.values
  }]]) : "${entry.domain}/${entry.name}" => entry }

  zone_id         = aws_route53_zone.this[each.value.domain].zone_id
  name            = trimprefix("${each.value.name}.${each.value.domain}", "#.")
  type            = "TXT"
  ttl             = each.value.ttl
  records         = each.value.values
  allow_overwrite = false
}

locals {
  txt_apex_records = flatten([for domain, zone in var.domains : [
    for name, record in try(contains(keys(zone.records), "#"), false) ? zone.records : {
      "#" = {
        type   = "txt"
        ttl    = 300
        values = []
      } } : {
      domain = domain
      type   = "txt"
      ttl    = record.ttl
      values = setunion(
        record.values,
        anytrue([
          for value in record.values : length(regexall("^v=spf", value)) > 0
        ]) ? [] : try([local.email_provider[zone.email].spf], [])
      )
  } if contains(["#", "!"], name) && record.type == "txt"]])

  txt = { for domain, zone in var.domains : domain => merge(
    { for name, record in zone.records : name => record if record.type == "txt" },
    { for entry in local.txt_apex_records : "#" => entry if entry.domain == domain && length(entry.values) > 0 }
  ) }
}
