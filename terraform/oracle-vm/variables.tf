variable "tenancy_ocid" {
  description = "Tenancy OCID (Profile -> Tenancy in the OCI console)."
  type        = string
}

variable "compartment_ocid" {
  description = "Compartment the VMs and network are created in. Defaults to the tenancy root compartment."
  type        = string
  default     = null
}

variable "region" {
  description = "Must be your tenancy's HOME region - Always Free A1 compute is only available there."
  type        = string
}

variable "oci_config_profile" {
  description = "Profile in ~/.oci/config to authenticate with."
  type        = string
  default     = "DEFAULT"
}

variable "availability_domain_index" {
  description = "Which availability domain (0-based) to place the VMs in. Change this if apply fails with 'Out of host capacity'."
  type        = number
  default     = 0
}

variable "vm_name_prefix" {
  description = "VMs are named <prefix>-<key of var.instances>, e.g. oracle-vm-prod."
  type        = string
  default     = "oracle-vm"
}

# ── Always Free limits for Ampere A1 (cut from 4/24 on 2026-06-15): 2 OCPU + 12GB RAM total across all A1 VMs,
# 200GB block storage total (boot volumes count towards it, min 47GB each) ──
variable "instances" {
  description = "VMs to create, keyed by role (name = <prefix>-<key>). public_web attaches the NSG that opens public_tcp_ports."
  type = map(object({
    public_web = bool
  }))
  default = {
    prod = { public_web = true }
    hlab = { public_web = false }
  }
}

variable "ocpus_per_instance" {
  description = "OCPUs per VM. number of instances * this must be <= 2 to stay free."
  type        = number
  default     = 1

  validation {
    condition     = var.ocpus_per_instance >= 1
    error_message = "ocpus_per_instance must be >= 1."
  }
}

variable "memory_gb_per_instance" {
  description = "RAM (GB) per VM. number of instances * this must be <= 12 to stay free."
  type        = number
  default     = 6
}

variable "boot_volume_gb" {
  description = "Boot volume size (GB) per VM. number of instances * this must be <= 200 to stay free; minimum 50."
  type        = number
  default     = 100

  validation {
    condition     = var.boot_volume_gb >= 50
    error_message = "boot_volume_gb must be >= 50."
  }
}

variable "boot_volume_vpus_per_gb" {
  description = "Boot volume performance units per GB (budget.tf guards the cost)."
  type        = number
  default     = 10

  validation {
    condition     = contains([10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120], var.boot_volume_vpus_per_gb)
    error_message = "boot_volume_vpus_per_gb must be a multiple of 10 between 10 and 120."
  }
}

variable "vpu_price_per_gb_month" {
  description = "List price of 1 VPU per GB per month in your billing currency, used only to estimate cost for the budget guardrail. Check https://www.oracle.com/cloud/price-list/ (Block Volume - Performance Units)."
  type        = number
  default     = 0.0023
}

variable "ssh_public_key_path" {
  description = "Public key installed for the `ubuntu` user."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to reach port 22. Narrow this to your IP (or drop to [] once Tailscale is up)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "public_tcp_ports" {
  description = "TCP ports open to the whole internet on VMs with public_web = true."
  type        = list(number)
  default     = [80, 443]
}

variable "budget_alert_email" {
  description = "Email that receives budget alerts if spend ever goes above zero."
  type        = string
}

variable "budget_amount" {
  description = "Monthly budget in your account's billing currency (SGD). Alerts fire at 50/80/100/120% of actual spend and when the forecast passes 100%. Plans fail if estimated VPU cost exceeds it."
  type        = number
  default     = 1

  validation {
    condition     = var.budget_amount > 0
    error_message = "budget_amount must be > 0."
  }
}

variable "early_alert_amounts" {
  description = "Absolute monthly spend amounts (billing currency, SGD) that each trigger an early-warning email."
  type        = list(number)
  default     = [1, 5]
}
