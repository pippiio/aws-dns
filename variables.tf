variable "config" {
  type = map(object({
    webredirect = optional(string)

    records = optional(map(object({
      type   = string
      values = set(string)
      ttl    = optional(number, 3600)
    })), {})

    additional_behaviors = optional(map(object({
      origin_protocol_policy   = optional(string, "https-only")
      allowed_methods          = optional(set(string), ["GET", "HEAD", "OPTIONS"])
      cached_methods           = optional(set(string), ["GET", "HEAD"])
      cache_policy             = optional(string, "Managed-CachingDisabled")
      origin_request_policy    = optional(string, "Managed-AllViewer")
      response_headers_policy  = optional(string, "Managed-SecurityHeadersPolicy")
      viewer_request_function  = optional(string)
      viewer_response_function = optional(string)
    })), {})
  }))

  # validation {
  #   error_message = format("config.webredirect cannot be used in combination with zone.records. The following entries are invalid: [%s].",
  #   join(", ", [for name, zone in var.config : name if zone.webredirect != null && length(zone.records) > 0]))
  #   condition = length([for name, zone in var.config : name if zone.webredirect != null && length(zone.records) > 0]) == 0
  # }
}
