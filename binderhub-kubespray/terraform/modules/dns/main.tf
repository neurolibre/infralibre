provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_record" "domain" {
  count   = length([var.binderhub_subdomain, var.jupyterhub_subdomain, var.grafana_subdomain, var.prometheus_subdomain])
  zone_id = var.cloudflare_zone_id
  name    = [var.binderhub_subdomain, var.jupyterhub_subdomain, var.grafana_subdomain, var.prometheus_subdomain][count.index]
  content = var.floating_ip
  type    = "A"
  proxied = true
}