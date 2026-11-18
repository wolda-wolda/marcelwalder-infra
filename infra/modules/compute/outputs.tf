output "instance_ids" {
  description = "Map of instance key to OCI instance OCID."
  value       = { for k, inst in oci_core_instance.this : k => inst.id }
}

output "private_ips" {
  description = "Map of instance key to primary private IP address."
  value       = { for k, inst in oci_core_instance.this : k => inst.private_ip }
}

output "public_ips" {
  description = "Map of instance key to effective public IP address (reserved or ephemeral)."
  value = {
    for k, inst in oci_core_instance.this : k => coalesce(
      try(oci_core_public_ip.reserved[k].ip_address, null),
      inst.public_ip
    )
  }
}

output "boot_volume_ids" {
  description = "Map of instance key to OCI boot volume OCID."
  value       = { for k, inst in oci_core_instance.this : k => inst.boot_volume_id }
}
