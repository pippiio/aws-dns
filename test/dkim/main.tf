//Der skal oprettes 3 DNS CNAME records, vha aws_route53_record tf resource typen (protonmail)

variable "domains" {
  type = map(object({
    email = optional(string, "disabled")
    dkim = optional(map(object({
      cname = optional(string, "")
    })))
  }))
}

variable "zone_id" {
  type = string
}

resource "aws_route53_record" "protonmail" {
  for_each = { for entry in flatten([         # Flatten the list of DKIM entries across all domains and domain keys.
    for domain, config in var.domains : [     # Iterate over all domains in the var.domains input variable.
      for domainKey, value in config.dkim : { # Iterates over domain keys
        domain    = domain
        domainKey = domainKey
        cname     = value.cname
    }] if config.email == "protonmail"]) : "${entry.domain}/${entry.domainKey}" => entry
  }

  zone_id = var.zone_id
  name    = format("%s.%s", each.value.domainKey, each.value.domain)
  type    = "CNAME"
  ttl     = 300
  records = [each.value.cname]
}

