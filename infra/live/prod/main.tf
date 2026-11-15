locals {
  mail_ingress_rules = [
    { description = "SSH", protocol = "6", source = "0.0.0.0/0", tcp_min = 22, tcp_max = 22 },
    { description = "SMTP Inbound", protocol = "6", source = "0.0.0.0/0", tcp_min = 25, tcp_max = 25 },
    { description = "HTTP ACME", protocol = "6", source = "0.0.0.0/0", tcp_min = 80, tcp_max = 80 },
    { description = "HTTPS", protocol = "6", source = "0.0.0.0/0", tcp_min = 443, tcp_max = 443 },
    { description = "SMTPS", protocol = "6", source = "0.0.0.0/0", tcp_min = 465, tcp_max = 465 },
    { description = "Submission", protocol = "6", source = "0.0.0.0/0", tcp_min = 587, tcp_max = 587 },
    { description = "IMAPS", protocol = "6", source = "0.0.0.0/0", tcp_min = 993, tcp_max = 993 },
  ]
}

module "network" {
  source = "../../modules/network"

  compartment_id        = var.compartment_id
  vcn_display_name      = "Mail-VCN"
  vcn_cidr_blocks       = ["10.0.0.0/16"]
  vcn_dns_label         = "mailvcn"
  igw_display_name      = "Mail-IGW"
  default_ingress_rules = local.mail_ingress_rules

  subnets = {
    public = {
      display_name = "Mail-Subnet"
      cidr_block   = "10.0.1.0/24"
      dns_label    = "mailsubnet"
    }
  }

  nsgs = var.nsgs
}

module "compute" {
  source = "../../modules/compute"

  compartment_id      = var.compartment_id
  ssh_authorized_keys = var.ssh_authorized_keys

  instances = {
    for k, inst in var.instances : k => {
      display_name            = inst.display_name
      availability_domain     = inst.availability_domain
      fault_domain            = inst.fault_domain
      shape                   = inst.shape
      ocpus                   = inst.ocpus
      memory_in_gbs           = inst.memory_in_gbs
      image_id                = inst.image_id
      boot_volume_size_in_gbs = inst.boot_volume_size_in_gbs
      boot_volume_vpus_per_gb = inst.boot_volume_vpus_per_gb
      subnet_id               = module.network.subnet_ids[inst.subnet_key]
      hostname_label          = inst.hostname_label
      private_ip              = inst.private_ip
      nsg_ids                 = [for nsg_key in inst.nsg_keys : module.network.nsg_ids[nsg_key]]
      vnic_assign_public_ip   = inst.vnic_assign_public_ip
      reserved_public_ip_name = inst.reserved_public_ip_name
      user_data_base64        = inst.user_data_base64
      freeform_tags           = inst.freeform_tags
    }
  }
}
