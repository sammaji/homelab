locals {
  sammaji_subdomains = toset([
    "bifrost",
    "dostack",
    "grafana",
    "infisical",
    "medatlas",
    "n8n",
    "nocodb",
  ])
}

# ── sammaji.com subdomains ──
resource "cloudflare_dns_record" "sammaji_com" {
  for_each = local.sammaji_subdomains

  zone_id = data.cloudflare_zone.sammaji_com.id
  name    = "${each.key}.sammaji.com"
  type    = "A"
  content = var.vps_ip
  proxied = false
  ttl     = 60
}

# ── budget-bee.app subdomains ──
resource "cloudflare_dns_record" "api_budget_bee_app" {
  zone_id = data.cloudflare_zone.budget_bee_app.id
  name    = "api.budget-bee.app"
  type    = "A"
  content = var.vps_ip
  proxied = false
  ttl     = 60
}
