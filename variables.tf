variable "config" {
  type = map(object({
    enable_fastmail = optional(bool, true)
    webredirect     = optional(string)

    records = optional(map(object({
      type   = string
      values = set(string)
      ttl    = optional(number, 3600)
    })), {})
  }))

  validation {
    error_message = format("config.webredirect cannot be used in combination with zone.records. The following entries are invalid: [%s].",
    join(", ", [for name, zone in var.config : name if zone.webredirect != null && length(zone.records) > 0]))
    condition = length([for name, zone in var.config : name if zone.webredirect != null && length(zone.records) > 0]) == 0
  }
}
