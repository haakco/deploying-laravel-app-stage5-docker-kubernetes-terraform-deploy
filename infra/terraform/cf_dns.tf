data "cloudflare_zones" "dns-domain" {
  filter {
    name = var.dns_domain
  }
}
