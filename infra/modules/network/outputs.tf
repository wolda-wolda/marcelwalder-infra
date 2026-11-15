output "vcn_id" {
  description = "OCID of the VCN."
  value       = oci_core_vcn.this.id
}

output "subnet_ids" {
  description = "Map of subnet key to subnet OCID."
  value       = { for k, s in oci_core_subnet.this : k => s.id }
}

output "nsg_ids" {
  description = "Map of NSG key to NSG OCID."
  value       = { for k, n in oci_core_network_security_group.this : k => n.id }
}
