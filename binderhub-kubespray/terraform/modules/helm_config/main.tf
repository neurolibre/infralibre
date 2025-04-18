    resource "random_id" "token" {
      count       = 2 # For api_token and secret_token
      byte_length = 32
    }

    resource "local_file" "metallb_ipaddresspool" {
      content = templatefile("${path.module}/../../templates/deploy/metallb_ipaddresspool.yaml.tpl", {
        load_balancer_ip = var.load_balancer_ip
      })
      filename = "${path.module}/../../../helm-charts/metallb_ipaddresspool.yaml" # Adjusted path
    }

    resource "local_file" "metallb_l2advertisement" {
      content  = templatefile("${path.module}/../../templates/deploy/metallb_l2advertisement.yaml.tpl", {})
      filename = "${path.module}/../../../helm-charts/metallb_l2advertisement.yaml" # Adjusted path
    }

    resource "local_file" "metallb_bgp" {
      content = templatefile("${path.module}/../../templates/deploy/metallb-bgp.yaml.tpl", {
        load_balancer_ip = var.load_balancer_ip
        bgp_peer_address = var.master_private_ip
      })
      filename = "${path.module}/../../../helm-charts/metallb-bgp.yaml" # Adjusted path
    }

    resource "local_file" "secrets" {
      content = templatefile("${path.module}/../../templates/deploy/secrets.yaml.tpl", {
        api_token         = random_id.token[0].hex
        secret_token      = random_id.token[1].hex
        registry_url      = var.registry_url
        registry_username = var.registry_username
        registry_password = var.registry_password
      })
      filename = "${path.module}/../../../helm-charts/secrets.yaml" # Adjusted path
    }

    resource "local_file" "cinder_pv" {
      content = templatefile("${path.module}/../../templates/deploy/pv-cinder.yaml.tpl", {
        cinder_db_volume_id = var.cinder_db_volume_id
      })
      filename = "${path.module}/../../../helm-charts/pv-cinder.yaml" # Adjusted path
    }

    resource "local_file" "binderhub_values" {
      content = templatefile("${path.module}/../../templates/deploy/binderhub-values.yaml.tpl", {
        binderhub_domain     = var.main_domain
        binderhub_subdomain  = var.binderhub_subdomain
        jupyterhub_subdomain = var.jupyterhub_subdomain
        binderhub_version    = var.binderhub_version
        cluster_name         = var.cluster_name
        load_balancer_ip     = var.load_balancer_ip
      })
      filename = "${path.module}/../../../helm-charts/binderhub-values.yaml" # Adjusted path
    }

    resource "local_file" "binderhub_issuer" {
      content = templatefile("${path.module}/../../templates/deploy/production-binderhub-issuer.yaml.tpl", {
        email_contact = var.email_contact
      })
      filename = "${path.module}/../../../helm-charts/production-binderhub-issuer.yaml" # Adjusted path
    }

    resource "local_file" "nginx_ingress" {
      content = templatefile("${path.module}/../../templates/deploy/nginx-ingress.yaml.tpl", {
        load_balancer_ip = var.load_balancer_ip
      })
      filename = "${path.module}/../../../helm-charts/nginx-ingress.yaml" # Adjusted path
    }

    resource "local_file" "prometheus_values" {
      content = templatefile("${path.module}/../../templates/deploy/prometheus-values.yaml.tpl", {
        grafana_subdomain    = var.grafana_subdomain
        grafana_domain       = var.main_domain
        prometheus_subdomain = var.prometheus_subdomain
      })
      filename = "${path.module}/../../../helm-charts/prometheus-values.yaml" # Adjusted path
    }