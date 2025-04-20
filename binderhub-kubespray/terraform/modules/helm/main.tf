    resource "random_id" "token" {
      count       = 2 # For api_token and secret_token
      byte_length = 32
    }

    resource "local_file" "metallb_l2" {
      content  = templatefile("${path.module}/../../templates/manifests/metallb-l2.yaml.tpl", {
        load_balancer_ip = var.load_balancer_ip
      })
      filename = "${path.module}/../../../helm-charts/metallb-l2.yaml"
    }

    resource "local_file" "metallb_bgp" {
      content = templatefile("${path.module}/../../templates/manifests/metallb-bgp.yaml.tpl", {
        load_balancer_ip = var.load_balancer_ip
        bgp_peer_address = var.master_private_ip
      })
      filename = "${path.module}/../../../helm-charts/metallb-bgp.yaml" # Adjusted path
    }

    resource "local_file" "secrets" {
      content = templatefile("${path.module}/../../templates/manifests/secrets.yaml.tpl", {
        api_token         = random_id.token[0].hex
        secret_token      = random_id.token[1].hex
        registry_url      = var.registry_url
        registry_username = var.registry_username
        registry_password = var.registry_password
      })
      filename = "${path.module}/../../../helm-charts/secrets.yaml" # Adjusted path
    }

    resource "local_file" "cinder_pv" {
      content = templatefile("${path.module}/../../templates/manifests/pv-cinder.yaml.tpl", {
        cinder_db_volume_id = var.cinder_db_volume_id
      })
      filename = "${path.module}/../../../helm-charts/pv-cinder.yaml" # Adjusted path
    }

    resource "local_file" "binderhub_values" {
      content = templatefile("${path.module}/../../templates/manifests/binderhub-values.yaml.tpl", {
        binderhub_domain     = var.main_domain
        binderhub_subdomain  = var.binderhub_subdomain
        jupyterhub_subdomain = var.jupyterhub_subdomain
        binderhub_version    = var.binderhub_version
        cluster_name         = var.cluster_name
        load_balancer_ip     = var.load_balancer_ip
        is_load_balancer     = var.is_load_balancer
      })
      filename = "${path.module}/../../../helm-charts/binderhub-values.yaml" # Adjusted path
    }

    resource "local_file" "binderhub_issuer" {
      content = templatefile("${path.module}/../../templates/manifests/production-binderhub-issuer.yaml.tpl", {
        email_contact = var.email_contact
      })
      filename = "${path.module}/../../../helm-charts/production-binderhub-issuer.yaml" # Adjusted path
    }

    resource "local_file" "nginx_ingress" {
      content = templatefile("${path.module}/../../templates/manifests/nginx-ingress.yaml.tpl", {
        load_balancer_ip = var.load_balancer_ip
        is_load_balancer = var.is_load_balancer
      })
      filename = "${path.module}/../../../helm-charts/nginx-ingress.yaml" # Adjusted path
    }

    resource "local_file" "prometheus_values" {
      content = templatefile("${path.module}/../../templates/manifests/prometheus-values.yaml.tpl", {
        grafana_subdomain    = var.grafana_subdomain
        grafana_domain       = var.main_domain
        prometheus_subdomain = var.prometheus_subdomain
      })
      filename = "${path.module}/../../../helm-charts/prometheus-values.yaml" # Adjusted path
    }