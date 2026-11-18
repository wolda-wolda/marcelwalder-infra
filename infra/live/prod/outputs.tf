output "vcn_id" {
  description = "OCID of the primary VCN."
  value       = module.network.vcn_id
}

output "subnet_ids" {
  description = "Map of subnet OCIDs."
  value       = module.network.subnet_ids
}

output "instance_ids" {
  description = "Map of VM instance keys to OCI instance OCIDs."
  value       = module.compute.instance_ids
}

output "instance_private_ips" {
  description = "Map of VM instance keys to primary private IP addresses."
  value       = module.compute.private_ips
}

output "instance_public_ips" {
  description = "Map of VM instance keys to public IP addresses (consumed by DNS stack and Ansible)."
  value       = module.compute.public_ips
}

output "objectstorage_namespace" {
  description = "OCI Object Storage namespace for the compartment."
  value       = data.oci_objectstorage_namespace.this.namespace
}

output "backup_bucket_name" {
  description = "OCI Object Storage bucket used for encrypted Restic offsite backups."
  value       = oci_objectstorage_bucket.backups.name
}

output "tfstate_bucket_name" {
  description = "OCI Object Storage bucket storing OpenTofu remote state."
  value       = oci_objectstorage_bucket.tfstate.name
}

output "email_domain_id" {
  description = "OCI Email Delivery domain OCID."
  value       = oci_email_email_domain.marcelwalder_eu.id
}

output "dkim_dns_subdomain_name" {
  description = "DNS subdomain for the active OCI Email Delivery DKIM selector."
  value       = oci_email_dkim.dkim1.dns_subdomain_name
}

output "ons_topic_id" {
  description = "OCI ONS notification topic OCID for operational and quota alerts."
  value       = oci_ons_notification_topic.quota_alerts.topic_id
}

output "budget_id" {
  description = "OCI Zero-Spend-Guard budget OCID."
  value       = oci_budget_budget.zero_spend_guard.id
}
