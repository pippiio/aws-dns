locals {
  dkim_token_enabled = ["protonmail", "gmail"]
}

variable "email" {
  type = object({
    enable_strict_dmarc = optional(bool, false)
    default_postmaster  = optional(string)
  })
  default = {}
}

variable "domains" {
  type = map(object({
    disable_dnssec = optional(bool, false)
    webredirect    = optional(string)
    email          = optional(string, "disabled")
    postmaster     = optional(string)
    //DKIM identifier that the provider generates and we can't derive ourselves
    email_dkim_token = optional(string)

    records = optional(map(object({
      type = string
      values = map(object({
        geoproximity = optional(object({
          coordinates = object({
            latitude  = number
            longitude = number
          })
        }), null)
      }))
      ttl = optional(number, 3600)
    })), {})
  }))

  validation {
    error_message = format("webredirect cannot be used in combination with records. The following entries are invalid: [%s].",
    join(", ", [for domain, zone in var.domains : domain if zone.webredirect != null && length(zone.records) > 0]))
    condition = length([for domain, zone in var.domains : domain if zone.webredirect != null && length(zone.records) > 0]) == 0
  }

  validation {
    error_message = format("'@' can only be used as apex identifier for A or REDIRECT records. The following entries are invalid: [%s].",
    join(", ", flatten([for domain, zone in var.domains : [for name, record in zone.records : "${name}.${domain}" if name == "@" && !contains(["a", "redirect"], record.type)]])))
    condition = length([
      for domain, zone in var.domains : [
        for name, record in zone.records : name if name == "@" && !contains(["a", "redirect"], record.type)
    ]]) > 0
  }

  validation {
    error_message = format("'#' can only be used as apex identifier for TXT records. The following entries are invalid: [%s].",
    join(", ", flatten([for domain, zone in var.domains : [for name, record in zone.records : "${name}.${domain}" if name == "#" && record.type != "txt"]])))
    condition = length([
      for domain, zone in var.domains : [
        for name, record in zone.records : name if name == "#" && record.type != "txt"
    ]]) > 0
  }

  validation {
    error_message = format("'$' can only be used as apex identifier for MX records. The following entries are invalid: [%s].",
    join(", ", flatten([for domain, zone in var.domains : [for name, record in zone.records : "${name}.${domain}" if name == "$" && record.type != "mx"]])))
    condition = length([
      for domain, zone in var.domains : [
        for name, record in zone.records : name if name == "$" && record.type != "mx"
    ]]) > 0
  }

  validation {
    error_message = format("Supported email providers includes [disabled, custom, fastmail, protonmail, gmail]. The following entries are invalid: [%s].",
      join(", ", [for domain, zone in var.domains : "${domain}:${zone.email}" if !contains(["disabled", "custom", "fastmail", "protonmail", "gmail"], zone.email)])
    )
    condition = alltrue([for domain, zone in var.domains : contains(["disabled", "custom", "fastmail", "protonmail", "gmail"], zone.email)])
  }
  //The token never contains dots, so a dot means the full hostname was pasted instead of just the identifier.
  validation {
    error_message = format("email_dkim_token must be the identifier only, not the full hostname. The following entries are invalid: [%s].",
      join(", ", [for domain, zone in var.domains : domain
    if zone.email_dkim_token != null && length(regexall("\\.", zone.email_dkim_token)) > 0]))
    condition = alltrue([for domain, zone in var.domains :
    zone.email_dkim_token == null || length(regexall("\\.", zone.email_dkim_token)) == 0])
  }
  //The token never contains dots, so a dot means the full hostname was pasted instead of just the identifier.
  validation {
    error_message = format("email_dkim_token is only supported for %s for now. Check your input [%s].",
      join(", ", local.dkim_token_enabled),
      join(", ", [for domain, zone in var.domains : domain
    if contains(local.dkim_token_enabled, zone.email) ? length(trim(coalesce(zone.email_dkim_token, " "), " ")) == 0 : length(trim(coalesce(zone.email_dkim_token, " "), " ")) > 0]))
    condition = alltrue([for domain, zone in var.domains :
    contains(local.dkim_token_enabled, zone.email) ? length(trim(coalesce(zone.email_dkim_token, " "), " ")) > 0 : true])
  }
}