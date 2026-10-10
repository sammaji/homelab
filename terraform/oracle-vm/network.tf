# ── Networking: 1 VCN + public subnet (Always Free covers 2 VCNs) ──
resource "oci_core_vcn" "this" {
  compartment_id = local.compartment_id
  display_name   = "${var.vm_name_prefix}-vcn"
  cidr_blocks    = ["10.0.0.0/16"]
  dns_label      = "oraclevm"
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.vm_name_prefix}-igw"
}

resource "oci_core_route_table" "public" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.vm_name_prefix}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

# Subnet-wide rules apply to every VM, so keep this to the bare minimum. All
# per-VM ingress lives in the NSGs below (OCI allows the union of both).
resource "oci_core_security_list" "public" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.vm_name_prefix}-public-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # ICMP fragmentation-needed, required for path MTU discovery
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "1"
    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_subnet" "public" {
  compartment_id    = local.compartment_id
  vcn_id            = oci_core_vcn.this.id
  display_name      = "${var.vm_name_prefix}-public-subnet"
  cidr_block        = "10.0.1.0/24"
  dns_label         = "public"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.public.id]
}

# ── NSG "base": attached to every VM - SSH + Tailscale only. No VCN-wide allow,
# so the VMs can't reach each other directly; they talk over Tailscale (ACLs). ──
resource "oci_core_network_security_group" "base" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.vm_name_prefix}-base-nsg"
}

resource "oci_core_network_security_group_security_rule" "ssh" {
  for_each = toset(var.ssh_allowed_cidrs)

  network_security_group_id = oci_core_network_security_group.base.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = each.value
  source_type               = "CIDR_BLOCK"
  description               = "SSH"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# Tailscale direct connections (WireGuard) - avoids falling back to DERP relays
resource "oci_core_network_security_group_security_rule" "tailscale" {
  network_security_group_id = oci_core_network_security_group.base.id
  direction                 = "INGRESS"
  protocol                  = "17" # UDP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  description               = "Tailscale direct"
  udp_options {
    destination_port_range {
      min = 41641
      max = 41641
    }
  }
}

# ── NSG "web": only on VMs with public_web = true (prod) ──
resource "oci_core_network_security_group" "web" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.vm_name_prefix}-web-nsg"
}

resource "oci_core_network_security_group_security_rule" "web" {
  for_each = toset([for p in var.public_tcp_ports : tostring(p)])

  network_security_group_id = oci_core_network_security_group.web.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  description               = "Public TCP ${each.value}"
  tcp_options {
    destination_port_range {
      min = tonumber(each.value)
      max = tonumber(each.value)
    }
  }
}
