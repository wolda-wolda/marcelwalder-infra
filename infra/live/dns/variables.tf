variable "domain" {
  description = "Primary domain name managed on Porkbun."
  type        = string
  default     = "marcelwalder.eu"
}

variable "state_passphrase" {
  description = "Passphrase for client-side OpenTofu AES-GCM state encryption."
  type        = string
  sensitive   = true
}

variable "extra_records" {
  description = "Additional Porkbun DNS records (e.g. subdomains pointing to new VMs)."
  type = map(object({
    subdomain = optional(string)
    type      = string
    content   = string
    ttl       = optional(number, 600)
    priority  = optional(number, 0)
    notes     = optional(string)
  }))
  default = {}
}
