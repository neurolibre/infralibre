    output "metallb_ipaddresspool_file_path" {
      value = local_file.metallb_ipaddresspool.filename
    }
    output "metallb_l2advertisement_file_path" {
      value = local_file.metallb_l2advertisement.filename
    }
    output "metallb_bgp_file_path" {
      value = local_file.metallb_bgp.filename
    }
    output "secrets_file_path" {
      value = local_file.secrets.filename
    }
    output "cinder_pv_file_path" {
      value = local_file.cinder_pv.filename
    }
    output "binderhub_values_file_path" {
      value = local_file.binderhub_values.filename
    }
    output "binderhub_issuer_file_path" {
      value = local_file.binderhub_issuer.filename
    }
    output "nginx_ingress_file_path" {
      value = local_file.nginx_ingress.filename
    }
    output "prometheus_values_file_path" {
      value = local_file.prometheus_values.filename
    }