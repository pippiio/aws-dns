locals {
  dmarc = var.email.enable_strict_dmarc ? "v=DMARC1; p=reject; rua=mailto:%s; adkim=s; aspf=s;" : "v=DMARC1; p=quarantine; rua=mailto:%s;"
  email_provider = {
    disabled = {
      mx_wildcard = false
      mx          = []
      spf         = "v=spf1 ~all"
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
        "fm1._domainkey" = "fm1.<domain>.dkim.fmhosted.com"
        "fm2._domainkey" = "fm2.<domain>.dkim.fmhosted.com"
        "fm3._domainkey" = "fm3.<domain>.dkim.fmhosted.com"
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
  for_each = { for entry in flatten([for domain, zone in var.domains : [
    for name, record in local.email_provider[zone.email].dkim : {
      domain = domain
      name   = name
      record = replace(record, "/<domain>/", domain)
    }]
  ]) : "${entry.domain}/${entry.name}" => entry }

  zone_id         = aws_route53_zone.this[each.value.domain].zone_id
  name            = each.value.name
  type            = "CNAME"
  ttl             = 300
  records         = [each.value.record]
  allow_overwrite = false
}
