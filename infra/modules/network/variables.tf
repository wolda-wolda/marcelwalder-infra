variable "compartment_id" {
  description = "OCI compartment OCID where network resources live."
  type        = string
}

variable "vcn_display_name" {
  description = "Display name of the VCN."
  type        = string
}

variable "vcn_cidr_blocks" {
  description = "IPv4 CIDR blocks assigned to the VCN."
  type        = list(string)
}

variable "vcn_dns_label" {
  description = "DNS label for the VCN."
  type        = string
}

variable "igw_display_name" {
  description = "Display name for the Internet Gateway."
  type        = string
  default     = "igw"
}

variable "default_ingress_rules" {
  description = "Ingress rules applied to the VCN default security list."
  type = list(object({
    description = optional(string)
    protocol    = string
    source      = string
    source_type = optional(string, "CIDR_BLOCK")
    stateless   = optional(bool, false)
    tcp_min     = optional(number)
    tcp_max     = optional(number)
    udp_min     = optional(number)
    udp_max     = optional(number)
  }))
  default = []
}

variable "subnets" {
  description = "Map of subnets to create inside the VCN."
  type = map(object({
    display_name               = string
    cidr_block                 = string
    dns_label                  = string
    prohibit_internet_ingress  = optional(bool, false)
    prohibit_public_ip_on_vnic = optional(bool, false)
  }))
}

variable "nsgs" {
  description = "Optional map of Network Security Groups and ingress rules for workloads/future VMs."
  type = map(object({
    display_name = string
    ingress_rules = optional(list(object({
      description = optional(string)
      protocol    = string
      source      = string
      source_type = optional(string, "CIDR_BLOCK")
      stateless   = optional(bool, false)
      tcp_min     = optional(number)
      tcp_max     = optional(number)
      udp_min     = optional(number)
      udp_max     = optional(number)
    })), [])
    egress_allow_all = optional(bool, true)
  }))
  default = {}
}
