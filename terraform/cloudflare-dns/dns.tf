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
    "@" : "97378c52d48be7eb.vercel-dns-017.com"
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

# GoHighLevel custom domain (funnel testing)
resource "cloudflare_dns_record" "ghl_sammaji_com" {
  zone_id = data.cloudflare_zone.sammaji_com.id
  name    = "ghl.sammaji.com"
  type    = "CNAME"
  content = "sites.ludicrous.cloud"
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

# ── watchthat.site CNAME records ──
resource "cloudflare_dns_record" "watchthat_site_cnames" {

  for_each = local.watchthat_site_cnames

  zone_id = data.cloudflare_zone.watchthat_site.id
  name    = each.key == "@" ? "@" : "${each.key}.watchthat.site"
  type    = "CNAME"
  content = each.value
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
