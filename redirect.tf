locals {
  redirect_domains = merge(
    merge([for domain, zone in var.config : {
      "${domain}" = {
        zone   = domain
        record = "@"
        values = [zone.webredirect]
      }
      "www.${domain}" = {
        zone   = domain
        record = "www"
        values = [zone.webredirect]
      }
    } if zone.webredirect != null]...),
    merge(flatten([for domain, zone in var.config : [
      for subdomain, record in zone.records : {
        replace("${subdomain}.${domain}", "/^@\\./", "") = {
          zone   = domain
          record = subdomain
          values = record.values
        }
      } if record.type == "redirect"
    ]])...)
  )

  redirect_zones = merge(
    { for domain, zone in var.config : domain => tolist([domain, "www.${domain}"]) if zone.webredirect != null },
    { for domain, zone in var.config : domain => tolist(sort([for subdomain, record in zone.records : replace("${subdomain}.${domain}", "/^@\\./", "")
      if lower(record.type) == "redirect"]
    )) if length([for record in values(zone.records) : record if lower(record.type) == "redirect"]) > 0 }
  )
}

resource "aws_acm_certificate" "redirect" {
  for_each = local.redirect_zones
  provider = aws.use1

  domain_name               = each.value[0]
  subject_alternative_names = each.value
  validation_method         = "DNS"
  tags                      = local.default_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "redirect_certificate" {
  for_each = { for entry in flatten([
    for zone, redirects in local.redirect_zones : [
      for redirect in redirects : {
        zone  = zone
        index = index(redirects, redirect)

  }]]) : "${entry.zone}/${entry.index}" => entry }

  zone_id         = aws_route53_zone.this[each.value.zone].zone_id
  name            = tolist(aws_acm_certificate.redirect[each.value.zone].domain_validation_options)[each.value.index].resource_record_name
  records         = [tolist(aws_acm_certificate.redirect[each.value.zone].domain_validation_options)[each.value.index].resource_record_value]
  type            = "CNAME"
  ttl             = 3600
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "redirect" {
  for_each = local.redirect_zones
  provider = aws.use1

  certificate_arn = aws_acm_certificate.redirect[each.key].arn
  validation_record_fqdns = [
    for record in values(aws_route53_record.redirect_certificate) : record.fqdn
    if record.zone_id == aws_route53_zone.this[each.key].zone_id
  ]
}

resource "aws_cloudfront_distribution" "redirect" {
  for_each = local.redirect_zones

  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"
  aliases             = each.value
  wait_for_deployment = false
  comment             = "Cloudfront CDN for redirects on ${each.key}"
  tags                = local.default_tags

  origin {
    domain_name = each.key
    origin_id   = "self"

    custom_origin_config {
      origin_protocol_policy = "match-viewer"
      http_port              = 80
      https_port             = 443
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "self"
    viewer_protocol_policy = "allow-all"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.redirect.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.redirect.arn
    }
  }
  dynamic "ordered_cache_behavior" {
    for_each = var.config.additional_behaviors

    content {
      path_pattern               = ordered_cache_behavior.key
      target_origin_id           = ordered_cache_behavior.value.origin
      allowed_methods            = ordered_cache_behavior.value.allowed_methods
      cached_methods             = ordered_cache_behavior.value.cached_methods
      cache_policy_id            = data.aws_cloudfront_cache_policy.additional[ordered_cache_behavior.key].id
      origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.additional[ordered_cache_behavior.key].id
      response_headers_policy_id = data.aws_cloudfront_response_headers_policy.additional[ordered_cache_behavior.key].id
      compress                   = true
      viewer_protocol_policy     = "redirect-to-https"

      dynamic "function_association" {
        for_each = ordered_cache_behavior.value.viewer_request_function != null ? [1] : []

        content {
          event_type   = "viewer-request"
          function_arn = ordered_cache_behavior.value.viewer_request_function
        }
      }

      dynamic "function_association" {
        for_each = ordered_cache_behavior.value.viewer_response_function != null ? [1] : []

        content {
          event_type   = "viewer-response"
          function_arn = ordered_cache_behavior.value.viewer_response_function
        }
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.redirect[each.key].certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}

resource "aws_cloudfront_function" "redirect" {
  name    = "redirect"
  runtime = "cloudfront-js-1.0"
  comment = "HTTP 301 redirect"
  publish = true
  code = templatefile("${path.module}/function/redirect.js", {
    redirects = { for domain, redirect in local.redirect_domains : domain => one(redirect.values) }
  })
}

resource "aws_route53_record" "redirect_cloudfront" {
  for_each = local.redirect_domains

  zone_id         = aws_route53_zone.this[each.value.zone].zone_id
  name            = each.key
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.redirect[each.value.zone].domain_name
    zone_id                = "Z2FDTNDATAQYW2" # AWS Cloudfront zone id
    evaluate_target_health = true
  }
}

data "aws_cloudfront_cache_policy" "redirect" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "additional" {
  for_each = var.config.additional_behaviors
  name = each.value.cache_policy
}

data "aws_cloudfront_origin_request_policy" "additional" {
  for_each = var.config.additional_behaviors
  name = each.value.origin_request_policy
}

data "aws_cloudfront_response_headers_policy" "additional" {
  for_each = var.config.additional_behaviors
  name = each.value.response_headers_policy
}
