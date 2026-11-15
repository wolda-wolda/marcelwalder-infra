variable "compartment_id" {
  description = "OCI compartment OCID for compute and reserved public IP resources."
  type        = string
}

variable "ssh_authorized_keys" {
  description = "List of SSH public keys injected into instance metadata."
  type        = list(string)
}

variable "instances" {
  description = "Map of VM instances to provision and manage."
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
    subnet_id               = string
    hostname_label          = string
    private_ip              = optional(string)
    nsg_ids                 = optional(list(string), [])
    vnic_assign_public_ip   = optional(bool, false)
    reserved_public_ip_name = optional(string)
    user_data_base64        = optional(string)
    freeform_tags           = optional(map(string), {})
  }))
}
