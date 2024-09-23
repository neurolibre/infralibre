# OpenNebula provider configuration
provider "opennebula" {
  endpoint = var.one_endpoint
  username = var.one_username
  password = var.one_password
}

# Cloudflare provider
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# New Relic provider
provider "newrelic" {
  api_key = var.new_relic_api
  account_id = var.new_relic_account
}

# Get the image ID
data "opennebula_image" "ubuntu" {
  name = var.image_name
}

# Get the virtual network
data "opennebula_virtual_network" "network" {
  name = var.network_name
}

# Create the VM
resource "opennebula_virtual_machine" "server" {
  name        = "${var.project_name}-${var.server_flavor}-server"
  template_id = var.template_id
  cpu         = var.cpu
  vcpu        = var.vcpu
  memory      = var.memory

  context = {
    NETWORK  = data.opennebula_virtual_network.network.name
    ssh_public_key = file(var.ssh_public_key_path)
    user_data       = data.template_file.neurolibre_server.rendered
  }

  disk {
    image_id = data.opennebula_image.ubuntu.id
    size     = var.instance_volume_size
  }

  nic {
    network_id = data.opennebula_virtual_network.network.id
  }
}

resource "cloudflare_origin_ca_certificate" "origin_cert" {
  hostnames         = [var.server_domain]
  request_type      = "origin-rsa"
  requested_validity = 5475
  csr               = tls_cert_request.cert_request.cert_request_pem
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "cert_request" {
  private_key_pem = tls_private_key.private_key.private_key_pem

  subject {
    common_name = var.server_domain
  }
}

resource "cloudflare_record" "domain" {
  zone_id = var.cloudflare_zone_id
  name    = var.server_subdomain
  value   = opennebula_virtual_machine.server.ip
  type    = "A"
}

data "template_file" "neurolibre_server" {
  template = file("${path.module}/neurolibre-server.yaml")
  vars = {
    ssh_authorized_keys = indent(2, join("\n", formatlist("- %s", var.ssh_authorized_keys)))
    volume_mount_point  = var.volume_mount_point
    server_flavor       = var.server_flavor
    api_username        = var.api_username
    api_password        = var.api_password
    server_domain       = var.server_domain
    server_subdomain    = var.server_subdomain
  }
}

resource "local_sensitive_file" "certificate" {
  content = base64encode(cloudflare_origin_ca_certificate.origin_cert.certificate)
  filename = "${path.module}/certificate.pem.base64"
  file_permission = "0644"
}

resource "local_sensitive_file" "private_key" {
  content = base64encode(tls_private_key.private_key.private_key_pem)
  filename = "${path.module}/private_key.pem.base64"
  file_permission = "0600"
}

resource "null_resource" "configure_server" {
  depends_on = [opennebula_virtual_machine.server]

  connection {
    type        = "ssh"
    user        = "root"
    host        = opennebula_virtual_machine.server.ip
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    source      = local_sensitive_file.private_key.filename
    destination = "/root/private_key.pem.base64"
  }

  provisioner "file" {
    source      = local_sensitive_file.certificate.filename
    destination = "/root/certificate.pem.base64"
  }

  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait > /dev/null",
      "sudo mkdir -p /etc/ssl",
      "sudo base64 -d /root/certificate.pem.base64 > /root/${var.server_domain}.pem",
      "sudo base64 -d /root/private_key.pem.base64 > /root/${var.server_domain}.key",
      "sudo chmod 644 /root/${var.server_domain}.pem",
      "sudo chmod 600 /root/${var.server_domain}.key",
      "sudo mv /root/${var.server_domain}.key /etc/ssl/${var.server_domain}.key",
      "sudo mv /root/${var.server_domain}.pem /etc/ssl/${var.server_domain}.pem",
      "sudo systemctl enable neurolibre-${var.server_flavor}.service",
      "sudo systemctl start neurolibre-${var.server_flavor}.service",
      "echo 'Started neurolibre-${var.server_flavor}'",
      "sudo systemctl enable neurolibre-celery.service",
      "sudo systemctl start neurolibre-celery.service",
      "echo 'Started neurolibre-celery'",
      "sudo systemctl restart nginx.service",
      "echo 'Started nginx'",
      "echo 'Installing New Relic Infrastructure Agent'",
      "echo \"license_key: ${var.new_relic_license}\" | sudo tee -a /etc/newrelic-infra.yml",
      "curl -fsSL https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/newrelic-infra.gpg",
      "echo \"deb https://download.newrelic.com/infrastructure_agent/linux/apt/ focal main\" | sudo tee -a /etc/apt/sources.list.d/newrelic-infra.list",
      "sudo apt-get update",
      "sudo apt-get install newrelic-infra -y"
    ]
  }
}

resource "newrelic_alert_policy" "high_cpu_policy" {
  name = "High CPU Policy"
}

resource "newrelic_alert_policy" "high_memory_policy" {
  name = "High Memory Policy"
}

resource "newrelic_nrql_alert_condition" "cpu_condition" {
  policy_id = newrelic_alert_policy.high_cpu_policy.id
  name      = "CPU Usage High"
  type      = "static"

  nrql {
    query = "SELECT average(cpuPercent) FROM SystemSample WHERE hostname LIKE '%'"
  }

  critical {
    operator              = "above"
    threshold             = 90
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

resource "newrelic_nrql_alert_condition" "memory_condition" {
  policy_id = newrelic_alert_policy.high_memory_policy.id
  name      = "Memory Usage High"
  type      = "static"

  nrql {
    query = "SELECT average(memoryUsedPercent) FROM SystemSample WHERE hostname LIKE '%'"
  }

  critical {
    operator              = "above"
    threshold             = 90
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

resource "newrelic_alert_channel" "email_channel" {
  name = "Admin Email"
  type = "email"

  config {
    recipients              = var.admin_email
    include_json_attachment = "false"
  }
}

resource "newrelic_alert_policy_channel" "email_policy" {
  policy_id   = newrelic_alert_policy.high_cpu_policy.id
  channel_ids = [newrelic_alert_channel.email_channel.id]
}