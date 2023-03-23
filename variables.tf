variable "domains" {
  type = map(object({
    disable_dnssec = optional(bool, false)
    webredirect    = optional(string)
    email          = optional(string, "disabled")
    postmaster     = optional(string)

    records = optional(map(object({
      type   = string
      values = set(string)
      ttl    = optional(number, 3600)
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
}

variable "email" {
  type = object({
    enable_strict_dmarc = optional(bool, false)
    default_postmaster  = optional(string)
  })
  default = {}
}
