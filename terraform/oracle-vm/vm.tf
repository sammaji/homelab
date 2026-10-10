# Latest Canonical Ubuntu 24.04 image built for ARM (A1)
data "oci_core_images" "ubuntu_arm" {
  compartment_id           = local.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# ── VMs: Ampere A1 Flex, one per entry in var.instances (default prod + hlab),
# each 1 OCPU / 6GB / 100GB = exactly the Always Free allowance ──
resource "oci_core_instance" "this" {
  for_each = var.instances

  compartment_id      = local.compartment_id
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[var.availability_domain_index].name
  display_name        = "${var.vm_name_prefix}-${each.key}"
  shape               = "VM.Standard.A1.Flex" # the only Always Free shape with real resources - other shapes are billed

  shape_config {
    ocpus         = var.ocpus_per_instance
    memory_in_gbs = var.memory_gb_per_instance
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true # ephemeral public IP - free; reserved IPs beyond the free allotment are billed
    hostname_label   = "${var.vm_name_prefix}-${each.key}"
    nsg_ids = concat(
      [oci_core_network_security_group.base.id],
      each.value.public_web ? [oci_core_network_security_group.web.id] : [],
    )
  }

  metadata = {
    ssh_authorized_keys = file(pathexpand(var.ssh_public_key_path))
  }

  # Don't leave orphaned boot volumes eating into the 200GB free storage after destroy
  preserve_boot_volume = false

  lifecycle {
    # Newer images get published regularly - don't recreate the VMs when they do
    ignore_changes = [source_details[0].source_id]

    precondition {
      condition     = length(var.instances) * var.ocpus_per_instance <= 2
      error_message = "Total OCPUs (${length(var.instances) * var.ocpus_per_instance}) exceed the Always Free limit of 2."
    }
    precondition {
      condition     = length(var.instances) * var.memory_gb_per_instance <= 12
      error_message = "Total memory (${length(var.instances) * var.memory_gb_per_instance}GB) exceeds the Always Free limit of 12GB."
    }
    precondition {
      condition     = length(var.instances) * var.boot_volume_gb <= 200
      error_message = "Total boot volume size (${length(var.instances) * var.boot_volume_gb}GB) exceeds the Always Free block storage limit of 200GB."
    }
  }
}
