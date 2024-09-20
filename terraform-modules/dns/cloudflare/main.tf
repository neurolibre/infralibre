

resource "cloudflare_record" "domain" {
  zone_id = var.zone_id
  name    = var.domain
  content = var.public_ip
  type    = "A"
}