terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

# CLOUDFLARE_API_TOKEN env var is read automatically by the provider
provider "cloudflare" {}

data "cloudflare_zone" "sammaji_com" {
  filter = {
    name = "sammaji.com"
  }
}

data "cloudflare_zone" "watchthat_site" {
  filter = {
    name = "watchthat.site"
  }
}

# oracle-vm-prod's public IP, from the oracle-vm module's state (apply that first).
data "terraform_remote_state" "oracle_vm" {
  backend = "local"
  config = {
    path = "${path.module}/../oracle-vm/terraform.tfstate"
  }
}

locals {
  prod_vm_ip = data.terraform_remote_state.oracle_vm.outputs.public_ips["oracle-vm-prod"]
}
