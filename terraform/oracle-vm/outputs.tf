output "public_ips" {
  description = "Ephemeral public IP of each VM"
  value       = { for i in oci_core_instance.this : i.display_name => i.public_ip }
}

output "private_ips" {
  description = "VCN-internal IP of each VM"
  value       = { for i in oci_core_instance.this : i.display_name => i.private_ip }
}

output "ssh_commands" {
  description = "SSH into each VM over Tailscale SSH (public 22 is closed once ssh_allowed_cidrs = [])"
  value       = { for i in oci_core_instance.this : i.display_name => "ssh ubuntu@${i.display_name}" }
}

output "image" {
  description = "Image the VMs were created from"
  value       = data.oci_core_images.ubuntu_arm.images[0].display_name
}
