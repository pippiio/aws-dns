locals {
  dmarc = var.email.enable_strict_dmarc ? "v=DMARC1; p=reject; rua=mailto:%s; adkim=s; aspf=s;" : "v=DMARC1; p=quarantine; rua=mailto:%s;"
  email_provider = {
    disabled = {
      mx_wildcard = false
      mx          = []
      spf         = "v=spf1 -all"
      dkim        = {}
    }

    custom = {
      mx_wildcard = false
      mx          = []
      spf         = "v=spf1 mx ~all"
      dkim        = {}
    }

    fastmail = {
      mx_wildcard = true
      mx = [
        "10 in1-smtp.messagingengine.com",
        "20 in2-smtp.messagingengine.com",
      ]
      spf = "v=spf1 include:spf.messagingengine.com ~all"
      dkim = {
        "fm1" = { cname = "fm1.%s.dkim.fmhosted.com" }
        "fm2" = { cname = "fm2.%s.dkim.fmhosted.com" }
        "fm3" = { cname = "fm3.%s.dkim.fmhosted.com" }
      }
    }

    protonmail = {
      mx_wildcard = false
      mx = [
        "10 mail.protonmail.ch",
        "20 mailsec.protonmail.ch",
      ]
      spf  = "v=spf1 include:_spf.protonmail.ch mx ~all"
      dkim = {}
    }

    gmail = {
      mx_wildcard = false
      mx = [
        "1 ASPMX.L.GOOGLE.COM",
        "5 ALT1.ASPMX.L.GOOGLE.COM",
        "5 ALT2.ASPMX.L.GOOGLE.COM",
        "10 ALT3.ASPMX.L.GOOGLE.COM",
        "10 ALT4.ASPMX.L.GOOGLE.COM",
      ]
      spf  = "v=spf1 include:_spf.google.com ~all"
      dkim = {}
    }
  }
}

resource "aws_route53_record" "mx" {
  for_each = { for domain, zone in var.domains : domain => zone.email if zone.email != null && try(length(local.email_provider[zone.email].mx) > 0, false) }

  zone_id         = aws_route53_zone.this[each.key].zone_id
  name            = ""
  type            = "MX"
  ttl             = 3600
  records         = local.email_provider[each.value].mx
  allow_overwrite = false
}

resource "aws_route53_record" "mx_wildcard" {
  for_each = { for domain, zone in var.domains : domain => zone.email if zone.email != null && try(local.email_provider[zone.email].mx_wildcard, false) }

  zone_id         = aws_route53_zone.this[each.key].zone_id
  name            = "*"
  type            = "MX"
  ttl             = 3600
  records         = local.email_provider[each.value].mx
  allow_overwrite = false
}

resource "aws_route53_record" "dmarc" {
  for_each = { for domain, zone in var.domains : domain => zone if try(!contains(keys(zone.records), "_dmarc"), true) }

  zone_id         = aws_route53_zone.this[each.key].zone_id
  name            = "_dmarc"
  type            = "TXT"
  ttl             = 300
  records         = [format(local.dmarc, coalesce(each.value.postmaster, var.email.default_postmaster, "postmaster@${each.key}"))]
  allow_overwrite = false
}

resource "aws_route53_record" "dkim" {
  for_each = { for _ in flatten([
    for _domain, _zone in var.domains : [
      for _selector, _record in _zone.dkim != null ? _zone.dkim : local.email_provider[_zone.email].dkim : {
        domain   = _domain
        selector = _selector
        type     = _record.cname != null ? "CNAME" : "TXT"
        value    = _record.cname != null ? try(format(_record.cname, _domain), "") : format("v=%s; k=%s; p=%s", _record.v, _record.k, _record.p)
      }
  ]]) : "${_.domain}/${_.selector}" => _ }

  zone_id         = aws_route53_zone.this[each.value.domain].zone_id
  name            = format("%s._domainkey.%s", each.value.selector, each.value.domain)
  type            = each.value.type
  ttl             = 300
  records         = [each.value.value]
  allow_overwrite = false
}
