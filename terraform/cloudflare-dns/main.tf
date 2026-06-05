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

data "cloudflare_zone" "budget_bee_app" {
  filter = {
    name = "budget-bee.app"
  }
}
