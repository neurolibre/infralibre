provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "newrelic" {
  api_key = var.new_relic_api
  account_id = var.new_relic_account
}

# Grab information about the image name 
# provided in the local (not version ctrld) main.tf
data "openstack_images_image_v2" "ubuntu" {
  name        = var.image_name
  most_recent = true
}

# =====================================================
# NOTE: We don't create/destroy these network resources
# they pre-exist. Hence, we just grab details to proceed.

# Get details of an existing PUBLIC network
data "openstack_networking_network_v2" "ext_network" {
  name = var.public_network
  external = true
}

# Get details of an existing INTERNAL network
# (that has its subnet) which is connected to the 
# Public-Network via a router.
data "openstack_networking_network_v2" "int_network" {
  name = var.cc_private_network
}
# =====================================================

# See cloud-init/kubeadm directory
data "template_cloudinit_config" "server_config" {
  part {
    filename     = "neurolibre-server.yaml"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = data.template_file.neurolibre_server.rendered
  }
}


# Grab details of a security group that HAS ALREADY BEEN
# attached to the nfs server (/DATA_NFS)
# The same security group is used for the server, necessary permissions
# are added in the security group module.
# You can use secgroup-common.tf to create the secgroup
data "openstack_networking_secgroup_v2" "neurolibre_nfs_secgroup" {
  name = var.nfs_secgroup_name
}

# Create a PORT under the internal network which will be attached to 
# the server VM with the security groups defined here.
resource "openstack_networking_port_v2" "server" {
  name               = "${var.project_name}-${var.server_flavor}-server"
  admin_state_up     = "true"
  network_id         = data.openstack_networking_network_v2.int_network.id
  security_group_ids = [
    data.openstack_networking_secgroup_v2.neurolibre_nfs_secgroup.id
  ]
}

# =====================================================  SERVER VM START
resource "openstack_blockstorage_volume_v3" "servervolume" {
  count       = var.existing_volume_uuid == "" ? 1 : 0
  name        = "${var.project_name}-${var.server_flavor}-ext-volume"
  size        = var.external_volume_size
}

data "openstack_compute_keypair_v2" "existing_keypair" {
  name = var.existing_keypair_name
}

resource "openstack_blockstorage_volume_v3" "mainvolume" {
  name        = "${var.project_name}-${var.server_flavor}-main-volume"
  size        = var.instance_volume_size
  image_id    = data.openstack_images_image_v2.ubuntu.id
}

resource "openstack_compute_instance_v2" "server" {
  name            = "${var.project_name}-${var.server_flavor}-server"
  flavor_name     = var.os_flavor_server
  key_pair        = data.openstack_compute_keypair_v2.existing_keypair.name
  #key_pair        = openstack_compute_keypair_v2.keypair.name
  security_groups = [
                    data.openstack_networking_secgroup_v2.neurolibre_nfs_secgroup.id]
  user_data       = data.template_cloudinit_config.server_config.rendered

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.mainvolume.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    port = openstack_networking_port_v2.server.id
  }
}
# =====================================================  SERVER VM END

resource "openstack_compute_volume_attach_v2" "attached" {
  instance_id = openstack_compute_instance_v2.server.id
  volume_id   = var.existing_volume_uuid != "" ? var.existing_volume_uuid : openstack_blockstorage_volume_v3.servervolume[0].id
}

# Create a floating IP in the external network pool
resource "openstack_networking_floatingip_v2" "fip_1" {
  pool = data.openstack_networking_network_v2.ext_network.name
}

# Attached the created floating IP to the PORT with security group
# linked to the server node. So that the floating IP is associated with
# the server node, as well as that secutiry group.
resource "openstack_networking_floatingip_associate_v2" "fip_1" {
  floating_ip = openstack_networking_floatingip_v2.fip_1.address
  port_id     = openstack_networking_port_v2.server.id
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
  content = openstack_networking_floatingip_v2.fip_1.address
  type    = "A"
}

data "template_file" "neurolibre_server" {
  template = file("${path.module}/neurolibre-server.yaml")
  vars = {
    ssh_authorized_keys = indent(2, join("\n", formatlist("- %s", var.ssh_authorized_keys)))
    volume_mount_point  = var.volume_mount_point
    volume_device       = var.existing_volume_uuid != "" ? "/dev/disk/by-uuid/${var.existing_volume_uuid}" : "/dev/disk/by-uuid/${openstack_blockstorage_volume_v3.servervolume[0].id}"
    server_flavor       = var.server_flavor
    api_username        = var.api_username
    api_password        = var.api_password
    server_domain       = var.server_domain
    server_subdomain    = var.server_subdomain
    use_existing_volume = var.existing_volume_uuid
    nfs_mnt_dir         = var.nfs_mnt_dir
    nfs_source_dir      = var.nfs_source_dir
    nfs_server_ip       = var.nfs_server_ip
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


resource "null_resource" "wait_for_cloud_init" {
  depends_on = [openstack_compute_instance_v2.server]

  connection {
    user        = "ubuntu"
    host        =  openstack_networking_floatingip_v2.fip_1.address
  }

  provisioner "file" {
          source = local_sensitive_file.private_key.filename
          destination = "/home/ubuntu/private_key.pem.base64"
  }

  provisioner "file" {
          source = local_sensitive_file.certificate.filename
          destination = "/home/ubuntu/certificate.pem.base64"
  }

  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait >> /dev/null"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "sudo mkdir -p /etc/ssl",
      "while [ ! -f /home/ubuntu/certificate.pem.base64 ]; do sleep 1; done",
      "while [ ! -f /home/ubuntu/private_key.pem.base64 ]; do sleep 1; done",
      "sudo base64 -d /home/ubuntu/certificate.pem.base64 > /home/ubuntu/${var.server_domain}.pem",
      "sudo base64 -d /home/ubuntu/private_key.pem.base64 > /home/ubuntu/${var.server_domain}.key",
      "sudo chmod 644 /home/ubuntu/${var.server_domain}.pem",
      "sudo chmod 600 /home/ubuntu/${var.server_domain}.key",
      "sudo chown root:root /home/ubuntu/${var.server_domain}.pem",
      "sudo chown root:root /home/ubuntu/${var.server_domain}.key",
      "sudo mv /home/ubuntu/${var.server_domain}.key /etc/ssl/${var.server_domain}.key",
      "sudo mv /home/ubuntu/${var.server_domain}.pem /etc/ssl/${var.server_domain}.pem",
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
      "echo \"deb https://download.newrelic.com/infrastructure_agent/linux/apt/ noble main\" | sudo tee -a /etc/apt/sources.list.d/newrelic-infra.list",
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
    recipients              =  var.admin_email
    include_json_attachment = "false"
  }
}

resource "newrelic_alert_policy_channel" "email_policy" {
  policy_id   = newrelic_alert_policy.high_cpu_policy.id
  channel_ids = [newrelic_alert_channel.email_channel.id]
}