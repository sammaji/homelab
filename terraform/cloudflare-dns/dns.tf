locals {
  sammaji_subdomains = {
    "bifrost" : local.hlab_vm_ip,  # /v1, /openai, /anthropic
    "listmonk" : local.hlab_vm_ip, # subscriber pages, SES webhook
    "n8n" : local.hlab_vm_ip,      # /webhook*
    "fitness" : var.vps_ip,
    "grafana" : var.vps_ip,
    "infisical" : var.vps_ip,
    "nocodb" : var.vps_ip,
  }

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
  content = each.value
  proxied = false
  ttl     = 60
}

resource "cloudflare_dns_record" "mkdp_sammaji_com" {
  zone_id = data.cloudflare_zone.sammaji_com.id
  name    = "mkdp.sammaji.com"
  type    = "CNAME"
  content = "2af578d901f7c9d8.vercel-dns-017.com"
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

resource "cloudflare_dns_record" "kai_sammaji_com" {
  zone_id = data.cloudflare_zone.sammaji_com.id
  name    = "kai.sammaji.com"
  type    = "CNAME"
  content = "7d77d3137040db9f.vercel-dns-017.com"
  proxied = false
  ttl     = 60
}

# ── Public records on oracle-vm-prod (public IP, read from terraform/oracle-vm) ──
resource "cloudflare_dns_record" "api_kai_sammaji_com" {
  zone_id = data.cloudflare_zone.sammaji_com.id
  name    = "api.kai.sammaji.com"
  type    = "A"
  content = local.prod_vm_ip
  proxied = false
  ttl     = 60
}

# Was a tailnet record on hlab; same Cloudflare record, now pointing at prod.
moved {
  from = cloudflare_dns_record.sammaji_com["api.kai"]
  to   = cloudflare_dns_record.api_kai_sammaji_com
}

resource "cloudflare_dns_record" "wts_sammaji_com" {
  zone_id = data.cloudflare_zone.sammaji_com.id
  name    = "wts.sammaji.com"
  type    = "CNAME"
  content = "f031a067f76f70d2.vercel-dns-017.com"
  proxied = false
  ttl     = 60
}

resource "cloudflare_dns_record" "docs_wts_sammaji_com" {
  zone_id = data.cloudflare_zone.sammaji_com.id
  name    = "docs.wts.sammaji.com"
  type    = "CNAME"
  content = "ec20fcd46674a8ab.vercel-dns-017.com"
  proxied = false
  ttl     = 60
}

resource "cloudflare_dns_record" "samplepages_wts_sammaji_com" {
  zone_id = data.cloudflare_zone.sammaji_com.id
  name    = "samplepages.wts.sammaji.com"
  type    = "CNAME"
  content = "d27b79dedcbdefc9.vercel-dns-017.com"
  proxied = false
  ttl     = 60
}

resource "cloudflare_dns_record" "docs_kai_sammaji_com" {
  zone_id = data.cloudflare_zone.sammaji_com.id
  name    = "docs.kai.sammaji.com"
  type    = "CNAME"
  content = "bbfc79eb87e91ef5.vercel-dns-017.com"
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
