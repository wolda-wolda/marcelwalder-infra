resource "porkbun_dns_record" "this" {
  for_each = var.records

  domain    = var.domain
  subdomain = each.value.subdomain
  type      = each.value.type
  content   = each.value.content
  ttl       = each.value.ttl
  priority  = each.value.priority
  notes     = each.value.notes
}
