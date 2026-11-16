resource "oci_core_instance" "this" {
  for_each = var.instances

  compartment_id      = var.compartment_id
  availability_domain = each.value.availability_domain
  fault_domain        = each.value.fault_domain
  display_name        = each.value.display_name
  shape               = each.value.shape
  freeform_tags       = each.value.freeform_tags

  shape_config {
    ocpus         = each.value.ocpus
    memory_in_gbs = each.value.memory_in_gbs
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  create_vnic_details {
    subnet_id        = each.value.subnet_id
    display_name     = each.value.display_name
    hostname_label   = each.value.hostname_label
    private_ip       = each.value.private_ip
    nsg_ids          = each.value.nsg_ids
    assign_public_ip = each.value.vnic_assign_public_ip
  }

  source_details {
    source_type             = "image"
    source_id               = each.value.image_id
    boot_volume_size_in_gbs = each.value.boot_volume_size_in_gbs
    boot_volume_vpus_per_gb = each.value.boot_volume_vpus_per_gb
  }

  metadata = merge(
    {
      ssh_authorized_keys = join("\n", var.ssh_authorized_keys)
    },
    each.value.user_data_base64 != null ? { user_data = each.value.user_data_base64 } : {}
  )

  lifecycle {
    ignore_changes = [
      defined_tags,
      source_details[0].boot_volume_size_in_gbs,
      source_details[0].boot_volume_vpus_per_gb,
      metadata["ssh_authorized_keys"],
    ]
  }
}

data "oci_core_vnic_attachments" "this" {
  for_each = var.instances

  compartment_id = var.compartment_id
  instance_id    = oci_core_instance.this[each.key].id
}

data "oci_core_private_ips" "this" {
  for_each = var.instances

  vnic_id = data.oci_core_vnic_attachments.this[each.key].vnic_attachments[0].vnic_id
}

resource "oci_core_public_ip" "reserved" {
  for_each = {
    for k, v in var.instances : k => v
    if v.reserved_public_ip_name != null
  }

  compartment_id = var.compartment_id
  lifetime       = "RESERVED"
  display_name   = each.value.reserved_public_ip_name
  private_ip_id  = data.oci_core_private_ips.this[each.key].private_ips[0].id

  lifecycle {
    ignore_changes = [defined_tags]
  }
}
