locals {
  mail_ingress_rules = [
    { description = "SSH", protocol = "6", source = "0.0.0.0/0", tcp_min = 22, tcp_max = 22 },
    { description = "SMTP Inbound", protocol = "6", source = "0.0.0.0/0", tcp_min = 25, tcp_max = 25 },
    { description = "HTTP ACME", protocol = "6", source = "0.0.0.0/0", tcp_min = 80, tcp_max = 80 },
    { description = "HTTPS", protocol = "6", source = "0.0.0.0/0", tcp_min = 443, tcp_max = 443 },
    { description = "SMTPS", protocol = "6", source = "0.0.0.0/0", tcp_min = 465, tcp_max = 465 },
    { description = "Submission", protocol = "6", source = "0.0.0.0/0", tcp_min = 587, tcp_max = 587 },
    { description = "IMAPS", protocol = "6", source = "0.0.0.0/0", tcp_min = 993, tcp_max = 993 },
    { description = "WireGuard Admin VPN", protocol = "17", source = "0.0.0.0/0", udp_min = 51820, udp_max = 51820 },
  ]

  email_senders = {
    info       = "info@marcelwalder.eu"
    postmaster = "postmaster@marcelwalder.eu"
    wildcard   = "*@marcelwalder.eu"
  }

  budget_alert_rules = {
    actual_70 = {
      display_name   = "Actual-Spend-70-Percent"
      type           = "ACTUAL"
      threshold      = 70
      threshold_type = "PERCENTAGE"
      message        = "OCI Alert: Actual spending has reached 70% of your 1.00 budget."
    }
    actual_90 = {
      display_name   = "Actual-Spend-90-Percent"
      type           = "ACTUAL"
      threshold      = 90
      threshold_type = "PERCENTAGE"
      message        = "OCI Alert: Urgent - Actual spending has reached 90% of your 1.00 budget."
    }
    forecast_70 = {
      display_name   = "Forecast-Spend-70-Percent"
      type           = "FORECAST"
      threshold      = 70
      threshold_type = "PERCENTAGE"
      message        = "OCI Alert: Forecasted spending is projected to reach 70% of your 1.00 budget."
    }
    forecast_90 = {
      display_name   = "Forecast-Spend-90-Percent"
      type           = "FORECAST"
      threshold      = 90
      threshold_type = "PERCENTAGE"
      message        = "OCI Alert: Warning - Forecasted spending is projected to reach 90% of your 1.00 budget."
    }
  }
}

data "oci_objectstorage_namespace" "this" {
  compartment_id = var.compartment_id
}

resource "oci_objectstorage_bucket" "backups" {
  compartment_id        = var.compartment_id
  namespace             = data.oci_objectstorage_namespace.this.namespace
  name                  = "backups-marcelwalder-prod"
  access_type           = "NoPublicAccess"
  storage_tier          = "Standard"
  auto_tiering          = "Disabled"
  object_events_enabled = false
  versioning            = "Enabled"

  lifecycle {
    ignore_changes = [defined_tags]
  }
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

  nsgs = merge(
    {
      mail = {
        display_name     = "Mail-Server-NSG"
        ingress_rules    = local.mail_ingress_rules
        egress_allow_all = true
      }
    },
    var.nsgs
  )
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

resource "oci_objectstorage_bucket" "tfstate" {
  compartment_id        = var.compartment_id
  namespace             = data.oci_objectstorage_namespace.this.namespace
  name                  = "tfstate-marcelwalder-prod"
  access_type           = "NoPublicAccess"
  storage_tier          = "Standard"
  auto_tiering          = "Disabled"
  object_events_enabled = false
  versioning            = "Enabled"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [defined_tags]
  }
}

resource "oci_objectstorage_object_lifecycle_policy" "backups" {
  namespace = data.oci_objectstorage_namespace.this.namespace
  bucket    = oci_objectstorage_bucket.backups.name

  depends_on = [oci_identity_policy.objectstorage_lifecycle]

  rules {
    name        = "expire-previous-versions"
    action      = "DELETE"
    target      = "previous-object-versions"
    time_amount = 30
    time_unit   = "DAYS"
    is_enabled  = true
  }

  rules {
    name        = "abort-stale-multipart-uploads"
    action      = "ABORT"
    target      = "multipart-uploads"
    time_amount = 7
    time_unit   = "DAYS"
    is_enabled  = true
  }
}

resource "oci_objectstorage_object_lifecycle_policy" "tfstate" {
  namespace = data.oci_objectstorage_namespace.this.namespace
  bucket    = oci_objectstorage_bucket.tfstate.name

  depends_on = [oci_identity_policy.objectstorage_lifecycle]

  rules {
    name        = "expire-previous-state-versions"
    action      = "DELETE"
    target      = "previous-object-versions"
    time_amount = 30
    time_unit   = "DAYS"
    is_enabled  = true
  }

  rules {
    name        = "abort-stale-multipart-uploads"
    action      = "ABORT"
    target      = "multipart-uploads"
    time_amount = 7
    time_unit   = "DAYS"
    is_enabled  = true
  }
}

resource "oci_core_volume_backup_policy" "mail" {
  compartment_id = var.compartment_id
  display_name   = "Always-Free-Mail-Backup-Policy"

  schedules {
    backup_type       = "INCREMENTAL"
    period            = "ONE_DAY"
    retention_seconds = 259200
    time_zone         = "REGIONAL_DATA_CENTER_TIME"
    offset_seconds    = 0
  }

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_core_volume_backup_policy_assignment" "mail_boot" {
  asset_id  = module.compute.boot_volume_ids["mail"]
  policy_id = oci_core_volume_backup_policy.mail.id
}

resource "oci_email_email_domain" "marcelwalder_eu" {
  compartment_id = var.compartment_id
  name           = "marcelwalder.eu"
  description    = "Email Domain for marcelwalder.eu"

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_email_dkim" "dkim1" {
  email_domain_id = oci_email_email_domain.marcelwalder_eu.id
  name            = "dkim1"

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_email_sender" "this" {
  for_each = local.email_senders

  compartment_id = var.compartment_id
  email_address  = each.value

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_ons_notification_topic" "quota_alerts" {
  compartment_id = var.compartment_id
  name           = "Free-Tier-Quota-Alerts"
  description    = "Notifications when Always Free resources approach 70% and 90% usage"

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_ons_subscription" "quota_alerts_email" {
  compartment_id = var.compartment_id
  topic_id       = oci_ons_notification_topic.quota_alerts.topic_id
  protocol       = "EMAIL"
  endpoint       = var.alert_email

  lifecycle {
    ignore_changes = [defined_tags, delivery_policy]
  }
}

resource "oci_events_rule" "mail_backup_notification" {
  compartment_id = var.compartment_id
  display_name   = "Mail-Server-Backup-Notification"
  is_enabled     = true

  condition_details {
    event_types = ["com.oraclecloud.blockstorage.createbootvolumebackup.end"]
    data        = jsonencode({})
  }

  actions {
    action {
      action_type = "ONS"
      description = "Notify when mail server boot volume backup finishes"
      is_enabled  = true
      topic_id    = oci_ons_notification_topic.quota_alerts.topic_id
    }
  }

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_monitoring_alarm" "instance_down_guard" {
  compartment_id                                = var.compartment_id
  metric_compartment_id                         = var.compartment_id
  metric_compartment_id_in_subtree              = false
  display_name                                  = "Always-Free-Instance-Down-Guard"
  namespace                                     = "oci_computeagent"
  query                                         = "CpuUtilization[5m]{resourceId = ${module.compute.instance_ids["mail"]}}.absent()"
  resolution                                    = "1m"
  pending_duration                              = "PT30M"
  evaluation_slack_duration                     = "PT3M"
  severity                                      = "CRITICAL"
  body                                          = "CRITICAL ALERT: Your Mail-Server instance has stopped emitting metrics for 30 minutes. The VM may be stopped or powered down. Please start or reboot it immediately to prevent downtime and avoid idle reclamation."
  is_enabled                                    = true
  is_notifications_per_metric_dimension_enabled = false
  message_format                                = "RAW"
  notification_title                            = "Always-Free-Instance-Down-Guard"
  notification_version                          = "1.X"
  rule_name                                     = "base"
  destinations                                  = [oci_ons_notification_topic.quota_alerts.topic_id]

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_monitoring_alarm" "idle_reclaim_guard_memory" {
  compartment_id                                = var.compartment_id
  metric_compartment_id                         = var.compartment_id
  metric_compartment_id_in_subtree              = false
  display_name                                  = "Always-Free-Idle-Reclaim-Guard-Memory"
  namespace                                     = "oci_computeagent"
  query                                         = "MemoryUtilization[1h]{resourceId = ${module.compute.instance_ids["mail"]}}.mean() < 20"
  resolution                                    = "1m"
  pending_duration                              = "PT12H"
  evaluation_slack_duration                     = "PT3M"
  severity                                      = "CRITICAL"
  body                                          = "CRITICAL ALERT: Your Mail-Server memory utilization has dropped below 20% for 12 hours. Oracle Always Free instances are subject to idle reclamation if CPU, Network, and Memory remain under 20% for 7 days. Please check your VM and ensure Docker-Mailserver is running."
  is_enabled                                    = true
  is_notifications_per_metric_dimension_enabled = false
  message_format                                = "RAW"
  notification_title                            = "Always-Free-Idle-Reclaim-Guard-Memory"
  notification_version                          = "1.X"
  rule_name                                     = "base"
  destinations                                  = [oci_ons_notification_topic.quota_alerts.topic_id]

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_budget_budget" "zero_spend_guard" {
  compartment_id                        = var.compartment_id
  display_name                          = "Zero-Spend-Guard"
  description                           = "Alert if any paid usage approaches 1 EUR/USD"
  amount                                = 1
  reset_period                          = "MONTHLY"
  processing_period_type                = "MONTH"
  budget_processing_period_start_offset = 1
  target_type                           = "COMPARTMENT"
  targets                               = [var.compartment_id]

  lifecycle {
    ignore_changes = [defined_tags, target_compartment_id]
  }
}

resource "oci_budget_alert_rule" "this" {
  for_each = local.budget_alert_rules

  budget_id      = oci_budget_budget.zero_spend_guard.id
  display_name   = each.value.display_name
  type           = each.value.type
  threshold      = each.value.threshold
  threshold_type = each.value.threshold_type
  recipients     = var.alert_email
  message        = each.value.message

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_identity_policy" "tenant_admin" {
  compartment_id = var.compartment_id
  name           = "Tenant Admin Policy"
  description    = "Tenant Admin Policy"
  statements = [
    "ALLOW GROUP Administrators to manage all-resources IN TENANCY"
  ]

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [defined_tags]
  }
}

data "oci_identity_domains" "default" {
  compartment_id = var.compartment_id
  display_name   = "Default"
}

resource "oci_identity_domains_user" "opentofu_ci" {
  idcs_endpoint = data.oci_identity_domains.default.domains[0].url
  schemas       = ["urn:ietf:params:scim:schemas:core:2.0:User"]
  user_name     = "opentofu-ci"
  display_name  = "OpenTofu CI Automation"
  description   = "Least-privilege service account for GitHub Actions OpenTofu CI/CD"
  active        = true

  name {
    given_name  = "OpenTofu"
    family_name = "CI"
  }

  emails {
    type    = "work"
    value   = var.alert_email
    primary = true
  }

  emails {
    type  = "recovery"
    value = var.alert_email
  }

  lifecycle {
    ignore_changes = [urnietfparamsscimschemasoracleidcsextension_oci_tags]
  }
}

resource "oci_identity_domains_group" "opentofu_ci" {
  idcs_endpoint = data.oci_identity_domains.default.domains[0].url
  schemas       = ["urn:ietf:params:scim:schemas:core:2.0:Group"]
  display_name  = "opentofu-ci"

  members {
    type  = "User"
    value = oci_identity_domains_user.opentofu_ci.id
    ocid  = oci_identity_domains_user.opentofu_ci.ocid
  }

  lifecycle {
    ignore_changes = [urnietfparamsscimschemasoracleidcsextension_oci_tags]
  }
}

resource "oci_identity_policy" "opentofu_ci" {
  compartment_id = var.compartment_id
  name           = "OpenTofu-CI-Least-Privilege"
  description    = "Least-privilege permissions for GitHub Actions OpenTofu CI/CD"
  statements = [
    "ALLOW GROUP 'Default'/'opentofu-ci' to manage virtual-network-family IN TENANCY",
    "ALLOW GROUP 'Default'/'opentofu-ci' to manage instance-family IN TENANCY",
    "ALLOW GROUP 'Default'/'opentofu-ci' to manage volume-family IN TENANCY",
    "ALLOW GROUP 'Default'/'opentofu-ci' to manage objectstorage-namespaces IN TENANCY",
    "ALLOW GROUP 'Default'/'opentofu-ci' to manage buckets IN TENANCY",
    "ALLOW GROUP 'Default'/'opentofu-ci' to manage objects IN TENANCY",
    "ALLOW GROUP 'Default'/'opentofu-ci' to manage email-family IN TENANCY",
    "ALLOW GROUP 'Default'/'opentofu-ci' to manage ons-family IN TENANCY",
    "ALLOW GROUP 'Default'/'opentofu-ci' to manage cloudevents-rules IN TENANCY",
    "ALLOW GROUP 'Default'/'opentofu-ci' to manage alarms IN TENANCY",
    "ALLOW GROUP 'Default'/'opentofu-ci' to manage usage-budgets IN TENANCY",
    "ALLOW GROUP 'Default'/'opentofu-ci' to read users IN TENANCY",
    "ALLOW GROUP 'Default'/'opentofu-ci' to read groups IN TENANCY",
    "ALLOW GROUP 'Default'/'opentofu-ci' to read policies IN TENANCY",
    "ALLOW GROUP 'Default'/'opentofu-ci' to read domains IN TENANCY"
  ]

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_identity_policy" "objectstorage_lifecycle" {
  compartment_id = var.compartment_id
  name           = "ObjectStorage-Lifecycle-Service-Principal"
  description    = "Allow OCI Object Storage service principal to execute bucket lifecycle rules"
  statements = [
    "ALLOW service objectstorage-eu-frankfurt-1 to manage object-family IN TENANCY"
  ]

  lifecycle {
    ignore_changes = [defined_tags]
  }
}
