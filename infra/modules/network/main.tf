resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_id
  cidr_blocks    = var.vcn_cidr_blocks
  display_name   = var.vcn_display_name
  dns_label      = var.vcn_dns_label

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = var.igw_display_name
  enabled        = true

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_core_default_route_table" "this" {
  manage_default_resource_id = oci_core_vcn.this.default_route_table_id
  display_name               = "Default Route Table for ${var.vcn_display_name}"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_core_default_security_list" "this" {
  manage_default_resource_id = oci_core_vcn.this.default_security_list_id
  display_name               = "Default Security List for ${var.vcn_display_name}"

  egress_security_rules {
    description      = "Allow all outbound"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = false
  }

  dynamic "ingress_security_rules" {
    for_each = var.default_ingress_rules
    content {
      description = ingress_security_rules.value.description
      protocol    = ingress_security_rules.value.protocol
      source      = ingress_security_rules.value.source
      source_type = ingress_security_rules.value.source_type
      stateless   = ingress_security_rules.value.stateless

      dynamic "tcp_options" {
        for_each = ingress_security_rules.value.tcp_min != null ? [1] : []
        content {
          min = ingress_security_rules.value.tcp_min
          max = coalesce(ingress_security_rules.value.tcp_max, ingress_security_rules.value.tcp_min)
        }
      }

      dynamic "udp_options" {
        for_each = ingress_security_rules.value.udp_min != null ? [1] : []
        content {
          min = ingress_security_rules.value.udp_min
          max = coalesce(ingress_security_rules.value.udp_max, ingress_security_rules.value.udp_min)
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_core_subnet" "this" {
  for_each = var.subnets

  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = each.value.cidr_block
  display_name               = each.value.display_name
  dns_label                  = each.value.dns_label
  prohibit_internet_ingress  = each.value.prohibit_internet_ingress
  prohibit_public_ip_on_vnic = each.value.prohibit_public_ip_on_vnic
  route_table_id             = oci_core_vcn.this.default_route_table_id
  security_list_ids          = [oci_core_vcn.this.default_security_list_id]
  dhcp_options_id            = oci_core_vcn.this.default_dhcp_options_id

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_core_network_security_group" "this" {
  for_each = var.nsgs

  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = each.value.display_name

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

locals {
  nsg_ingress_flat = flatten([
    for nsg_key, nsg in var.nsgs : [
      for idx, rule in nsg.ingress_rules : {
        key         = "${nsg_key}-in-${idx}"
        nsg_key     = nsg_key
        description = rule.description
        protocol    = rule.protocol
        source      = rule.source
        source_type = rule.source_type
        stateless   = rule.stateless
        tcp_min     = rule.tcp_min
        tcp_max     = rule.tcp_max
        udp_min     = rule.udp_min
        udp_max     = rule.udp_max
      }
    ]
  ])
}

resource "oci_core_network_security_group_security_rule" "ingress" {
  for_each = { for item in local.nsg_ingress_flat : item.key => item }

  network_security_group_id = oci_core_network_security_group.this[each.value.nsg_key].id
  direction                 = "INGRESS"
  protocol                  = each.value.protocol
  description               = each.value.description
  source                    = each.value.source
  source_type               = each.value.source_type
  stateless                 = each.value.stateless

  dynamic "tcp_options" {
    for_each = each.value.tcp_min != null ? [1] : []
    content {
      destination_port_range {
        min = each.value.tcp_min
        max = coalesce(each.value.tcp_max, each.value.tcp_min)
      }
    }
  }

  dynamic "udp_options" {
    for_each = each.value.udp_min != null ? [1] : []
    content {
      destination_port_range {
        min = each.value.udp_min
        max = coalesce(each.value.udp_max, each.value.udp_min)
      }
    }
  }
}

resource "oci_core_network_security_group_security_rule" "egress" {
  for_each = { for k, v in var.nsgs : k => v if v.egress_allow_all }

  network_security_group_id = oci_core_network_security_group.this[each.key].id
  direction                 = "EGRESS"
  protocol                  = "all"
  description               = "Allow all outbound"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  stateless                 = false
}
