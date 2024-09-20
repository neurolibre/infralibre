provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_record" "domain" {
  count   = length([var.grafana_subdomain, var.prometheus_subdomain])
  zone_id = var.cloudflare_zone_id
  name    = [var.grafana_subdomain, var.prometheus_subdomain][count.index]
  content = var.ip
  type    = "A"
  proxied = true
}

resource "random_id" "token" {
  count       = 2
  byte_length = 32
}

data "template_file" "config" {
  template = file("${path.module}/assets/config.yaml")
  vars = {
    domain          = var.domain
    TLS_name        = var.TLS_name
    cpu_alloc       = var.cpu_alloc
    mem_alloc       = var.mem_alloc_gb
    docker_registry = var.docker_registry
    docker_id       = var.docker_id
  }
}

data "template_file" "prod_config" {
  template = file("${path.module}/assets/prod-config.yaml")
  vars = {
    domain          = var.domain
    TLS_name        = var.TLS_name
    cpu_alloc       = var.cpu_alloc
    mem_alloc       = var.mem_alloc_gb
    docker_registry = var.docker_registry
    docker_id       = var.docker_id
    binderhub_subdomain = var.binderhub_subdomain
    binderhub_domain = var.binderhub_domain
    project_name    = var.project_name
  }
}

data "template_file" "secrets" {
  template = file("${path.module}/assets/secrets.yaml")
  vars = {
    api_token       = random_id.token[0].hex
    secret_token    = random_id.token[1].hex
    docker_registry = var.docker_registry
    docker_id       = var.docker_id
    docker_password = var.docker_password
  }
}

data "template_file" "production-binderhub-issuer" {
  template = file("${path.module}/assets/production-binderhub-issuer.yaml")
  vars = {
    domain    = var.domain
    TLS_email = var.TLS_email
  }
}

data "template_file" "staging-binderhub-issuer" {
  template = file("${path.module}/assets/staging-binderhub-issuer.yaml")
  vars = {
    domain    = var.domain
    TLS_email = var.TLS_email
  }
}

data "template_file" "install-binderhub" {
  template = file("${path.module}/assets/install-binderhub.sh")
  vars = {
    binder_version  = var.binder_version
    binder_deployment_yaml_config = var.binder_deployment_yaml_config
    admin_user      = var.admin_user
    docker_id       = var.docker_id
    docker_password = var.docker_password
    project_name    = var.project_name
  }
}

data "template_file" "cloudflare-secret" {
  template = file("${path.module}/assets/cloudflare-secret.yaml")
  vars = {
    cloudflare_token  = var.cloudflare_token
  }
}

data "template_file" "grafana_deploy" {
  template = file("${path.module}/grafana/grafana-deploy.yaml")
  vars = {
    grafana_admin_user     = var.grafana_admin_user
    grafana_admin_password = var.grafana_admin_password
  }
}

data "template_file" "grafana_ingress" {
  template = file("${path.module}/grafana/grafana-ingress.yaml")
  vars = {
    grafana_subdomain = var.grafana_subdomain
    binderhub_domain  = var.domain
  }
}

data "template_file" "prometheus_configmap" {
  template = file("${path.module}/prometheus/prometheus-configmap.yaml")
  vars = {
    binderhub_subdomain = var.binderhub_subdomain
    binderhub_domain    = var.domain
  }
}

data "template_file" "prometheus_ingress" {
  template = file("${path.module}/prometheus/prometheus-ingress.yaml")
  vars = {
    prometheus_subdomain = var.prometheus_subdomain
    binderhub_domain     = var.domain
  }
}

resource "terraform_data" "binderhub" {

connection {
  host = var.ip
  user = var.admin_user
  timeout = "10m"
}

provisioner "file" {
  content     = data.template_file.config.rendered
  destination = "/home/${var.admin_user}/config.yaml"
}

provisioner "file" {
  content     = data.template_file.prod_config.rendered
  destination = "/home/${var.admin_user}/prod-config.yaml"
}

provisioner "file" {
  content     = data.template_file.secrets.rendered
  destination = "/home/${var.admin_user}/secrets.yaml"
}

provisioner "file" {
  content     = data.template_file.production-binderhub-issuer.rendered
  destination = "/home/${var.admin_user}/production-binderhub-issuer.yaml"
}

provisioner "file" {
  content     = data.template_file.staging-binderhub-issuer.rendered
  destination = "/home/${var.admin_user}/staging-binderhub-issuer.yaml"
}

provisioner "file" {
  content     = data.template_file.install-binderhub.rendered
  destination = "/home/${var.admin_user}/install-binderhub.sh"
}

provisioner "file" {
  content     = data.template_file.cloudflare-secret.rendered
  destination = "/home/${var.admin_user}/cloudflare-secret.yaml"
}

provisioner "file" {
  source      = "${path.module}/assets/pv.yaml"
  destination = "/home/${var.admin_user}/pv.yaml"
}

provisioner "file" {
  source      = "${path.module}/grafana/grafana-ingress.yaml"
  destination = "/home/${var.admin_user}/grafana-ingress.yaml"
}

provisioner "file" {
  source      = "${path.module}/assets/nginx-ingress.yaml"
  destination = "/home/${var.admin_user}/nginx-ingress.yaml"
}

provisioner "file" {
  content     = data.template_file.grafana_deploy.rendered
  destination = "/home/${var.admin_user}/grafana-deploy.yaml"
}

provisioner "file" {
  content     = data.template_file.prometheus_configmap.rendered
  destination = "/home/${var.admin_user}/prometheus-configmap.yaml"
}

provisioner "file" {
  content     = data.template_file.prometheus_deploy.rendered
  destination = "/home/${var.admin_user}/prometheus-deploy.yaml"
}

provisioner "file" {
  content     = data.template_file.prometheus_ingress.rendered
  destination = "/home/${var.admin_user}/prometheus-ingress.yaml"
}

  provisioner "file" {
    source      = "${path.module}/prometheus/prometheus-service.yaml"
    destination = "/home/${var.admin_user}/prometheus-service.yaml"
  }

provisioner "file" {
  content     = data.template_file.prometheus_exporters.rendered
  destination = "/home/${var.admin_user}/prometheus-exporters.yaml"
}

provisioner "file" {
  source      = "${path.module}/assets/install-monitoring.sh"
  destination = "/home/${var.admin_user}/install-monitoring.sh"
}

provisioner "remote-exec" {
  inline = [
    "chmod +x /home/${var.admin_user}/install-binderhub.sh",
    "chmod +x /home/${var.admin_user}/install-monitoring.sh",
    "bash /home/${var.admin_user}/install-binderhub.sh",
    "bash /home/${var.admin_user}/install-monitoring.sh"
  ]
}
}