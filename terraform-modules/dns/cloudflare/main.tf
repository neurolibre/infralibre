provider "cloudflare" {
  version = "<= 2.10.1"
}

resource "cloudflare_record" "domain" {
  zone_id = "ae42bc72343b3e27ab10ad833086b679"
  name    = element(split(".", var.domain), 0)
  value   = var.public_ip
  type    = "A"
}

