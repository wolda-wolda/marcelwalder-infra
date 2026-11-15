output "record_ids" {
  description = "Map of logical record key to Porkbun DNS record ID."
  value       = { for k, r in porkbun_dns_record.this : k => r.id }
}
