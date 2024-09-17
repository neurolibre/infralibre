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
    deployment_type = var.deployment_type
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
  content     = data.template_file.pv.rendered
  destination = "/home/${var.admin_user}/pv.yaml"
}

provisioner "file" {
  content     = data.template_file.nginx-ingress.rendered
  destination = "/home/${var.admin_user}/nginx-ingress.yaml"
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

## DEPRECATED

# provisioner "file" {
#   source     = "${path.module}/assets/fill_submission_metadata.bash"
#   destination = "/home/${var.admin_user}/fill_submission_metadata.bash"
# }

# provisioner "file" {
#   source     = "${path.module}/assets/repo2data.bash"
#   destination = "/home/${var.admin_user}/repo2data.bash"
# }

# provisioner "file" {
#   source     = "${path.module}/assets/jb_build.bash"
#   destination = "/home/${var.admin_user}/jb_build.bash"
# }

provisioner "remote-exec" {
  inline = ["bash /home/${var.admin_user}/install-binderhub.sh",]
}
}