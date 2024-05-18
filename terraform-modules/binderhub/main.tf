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

data "template_file" "pv" {
  template = file("${path.module}/assets/pv.yaml")
  vars     = {}
}

data "template_file" "nginx-ingress" {
  template = file("${path.module}/assets/nginx-ingress.yaml")
  vars     = {}
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
    admin_user      = var.admin_user
    docker_id       = var.docker_id
    docker_password = var.docker_password
  }
}