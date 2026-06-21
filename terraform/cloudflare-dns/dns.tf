locals {
  sammaji_subdomains = toset([
    "bifrost",
    "dostack",
    "grafana",
    "infisical",
    "jellyfin",
    "medatlas",
    "n8n",
    "nocodb",
  ])

  watchthat_site_subdomains = toset([
    "proxy",
    "bifrost"
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

# ── watchthat.site subdomains ──
resource "cloudflare_dns_record" "watchthat_site" {
  for_each = local.watchthat_site_subdomains

  zone_id = data.cloudflare_zone.watchthat_site.id
  name    = "${each.key}.watchthat.site"
  type    = "A"
  content = var.vps_ip
  proxied = false
  ttl     = 60
}

resource "cloudflare_dns_record" "samplepages_watchthat_site" {
  zone_id = data.cloudflare_zone.watchthat_site.id
  name    = "samplepages.watchthat.site"
  type    = "CNAME"
  content = "d5803da95b8a2fe5.vercel-dns-017.com"
  proxied = false
  ttl     = 60
}
