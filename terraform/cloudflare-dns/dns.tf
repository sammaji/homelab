locals {
  sammaji_subdomains = toset([
    "bifrost",
    "dostack",
    "grafana",
    "infisical",
    "medatlas",
    "n8n",
    "nocodb",
    "paytrack",
  ])

  watchthat_site_subdomains = toset([
    "proxy",
    "bifrost"
  ])

  watchthat_site_cnames = {
    "www" : "97378c52d48be7eb.vercel-dns-017.com"
    "app" : "88ea97c7df9f77f8.vercel-dns-017.com"
    "docs" : "b34d63d85116b2ab.vercel-dns-017.com"
    "samplepages" : "d5803da95b8a2fe5.vercel-dns-017.com"
  }
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

resource "cloudflare_dns_record" "scp_sammaji_com" {
  zone_id = data.cloudflare_zone.sammaji_com.id
  name    = "scp.sammaji.com"
  type    = "CNAME"
  content = "e548a925ca8fd88a.vercel-dns-017.com"
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
resource "cloudflare_dns_record" "root_watchthat_site" {
  zone_id = data.cloudflare_zone.watchthat_site.id
  name    = "@"
  type    = "CNAME"
  content = "97378c52d48be7eb.vercel-dns-017.com"
  proxied = false
  ttl     = 60
}

resource "cloudflare_dns_record" "watchthat_site_cnames" {

  for_each = local.watchthat_site_cnames

  zone_id = data.cloudflare_zone.watchthat_site.id
  name    = "${each.key}.watchthat.site"
  type    = "CNAME"
  content = each.value
  proxied = false
  ttl     = 60
}

resource "cloudflare_dns_record" "watchthat_site" {
  for_each = local.watchthat_site_subdomains

  zone_id = data.cloudflare_zone.watchthat_site.id
  name    = "${each.key}.watchthat.site"
  type    = "A"
  content = var.vps_ip
  proxied = false
  ttl     = 60
}
