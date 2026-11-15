variable "domain" {
  description = "Primary domain managed in Porkbun."
  type        = string
}

variable "records" {
  description = "Map of Porkbun DNS records to manage declaratively."
  type = map(object({
    subdomain = optional(string)
    type      = string
    content   = string
    ttl       = optional(number, 600)
    priority  = optional(number, 0)
    notes     = optional(string)
  }))
}
