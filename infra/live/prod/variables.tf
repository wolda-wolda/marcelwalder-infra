variable "region" {
  description = "OCI region identifier."
  type        = string
  default     = "eu-frankfurt-1"
}

variable "compartment_id" {
  description = "OCI compartment OCID (supplied via TF_VAR_compartment_id or local tfvars)."
  type        = string
}

variable "state_passphrase" {
  description = "Passphrase for client-side OpenTofu AES-GCM state encryption (TF_VAR_state_passphrase)."
  type        = string
  sensitive   = true
}

variable "ssh_authorized_keys" {
  description = "SSH public keys authorized for VM instances."
  type        = list(string)
}

variable "instances" {
  description = "Map of OCI compute instances managed by this stack. Add a key here to provision another VM."
  type = map(object({
    display_name            = string
    availability_domain     = string
    fault_domain            = optional(string)
    shape                   = string
    ocpus                   = number
    memory_in_gbs           = number
    image_id                = string
    boot_volume_size_in_gbs = optional(number)
    boot_volume_vpus_per_gb = optional(number)
    subnet_key              = string
    hostname_label          = string
    private_ip              = optional(string)
    nsg_keys                = optional(list(string), [])
    vnic_assign_public_ip   = optional(bool, false)
    reserved_public_ip_name = optional(string)
    user_data_base64        = optional(string)
    freeform_tags           = optional(map(string), {})
  }))
}

variable "nsgs" {
  description = "Additional Network Security Groups for new workloads/VMs."
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

variable "alert_email" {
  description = "Administrative email address for OCI quota, alarm, backup, and budget notifications."
  type        = string
  default     = "marcelwalder12@gmail.com"
}
