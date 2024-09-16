provider "cloudflare" {
  api_token = var.cloudflare_api_token
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
    filename     = "server-common.yaml"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = data.template_file.server_common.rendered
  }
}


# Grab details of a security group that HAS ALREADY BEEN
# attached to the nfs server (/DATA_NFS)
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
    openstack_networking_secgroup_v2.common.id,
    data.openstack_networking_secgroup_v2.neurolibre_nfs_secgroup.id
  ]
}

# =====================================================  SERVER VM START
resource "openstack_blockstorage_volume_v3" "servervolume" {
  count       = var.existing_volume_uuid == "" ? 1 : 0
  name        = "${var.project_name}-${var.server_flavor}-volume"
  size        = var.instance_volume_size
  image_id    = data.openstack_images_image_v2.ubuntu.id
}

data "openstack_compute_keypair_v2" "existing_keypair" {
  name = var.existing_keypair_name
}

resource "openstack_compute_instance_v2" "server" {
  name            = "${var.project_name}-${var.server_flavor}-server"
  flavor_name     = var.os_flavor_server
  key_pair        = data.openstack_compute_keypair_v2.existing_keypair.name
  #key_pair        = openstack_compute_keypair_v2.keypair.name
  security_groups = [openstack_networking_secgroup_v2.common.id,
                    data.openstack_networking_secgroup_v2.neurolibre_nfs_secgroup.id]
  user_data       = data.template_cloudinit_config.server_config.rendered

  block_device {
    uuid                  = var.existing_volume_uuid != "" ? var.existing_volume_uuid : openstack_blockstorage_volume_v3.servervolume[0].id
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
  name    = var.server_domain
  content = openstack_networking_floatingip_v2.fip_1.address
  type    = "A"
}

data "template_file" "server_common" {
  template = file("${path.module}/../../../cloud-init/kubeadm/server-common.yaml")
  vars = {
    ssh_authorized_keys = indent(2, join("\n", formatlist("- %s", var.ssh_authorized_keys)))
    volume_mount_point  = var.volume_mount_point
    volume_device       = var.existing_volume_uuid != "" ? "/dev/disk/by-uuid/${var.existing_volume_uuid}" : "/dev/disk/by-uuid/${openstack_blockstorage_volume_v3.servervolume[0].id}"
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


resource "null_resource" "wait_for_cloud_init" {
  depends_on = [openstack_compute_instance_v2.server]

  connection {
    user        = "ubuntu"
    host        =  openstack_networking_floatingip_v2.fip_1.address
  }

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      max_retries=30
      counter=0
      until ssh -i ${var.ssh_private_key} -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@${openstack_networking_floatingip_v2.fip_1.address} echo "Host is ready"
      do
        if [ $counter -eq $max_retries ]
        then
          echo "Failed to connect after $max_retries attempts. Exiting."
          exit 1
        fi
        echo "Waiting for host to become available... (Attempt $((counter+1))/$max_retries)"
        sleep 10
        ((counter++))
      done

      scp -i ${var.ssh_private_key} -o StrictHostKeyChecking=no ${local_sensitive_file.certificate.filename} ${local_sensitive_file.private_key.filename} ubuntu@${openstack_networking_floatingip_v2.fip_1.address}:/home/ubuntu/
    EOT
  }

  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "sudo mkdir -p /etc/ssl",
      "sudo mv ${local_sensitive_file.certificate.filename} /etc/ssl/${var.server_domain}.pem",
      "sudo mv ${local_sensitive_file.private_key.filename} /etc/ssl/${var.server_domain}.key",
      "sudo chmod 644 /etc/ssl/${var.server_domain}.pem",
      "sudo chmod 600 /etc/ssl/${var.server_domain}.key",
      "sudo chown root:root /etc/ssl/${var.server_domain}.pem",
      "sudo chown root:root /etc/ssl/${var.server_domain}.key"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait >> /dev/null"
    ]
  }
}