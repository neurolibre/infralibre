provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "newrelic" {
  api_key = var.new_relic_api
  account_id = var.new_relic_account
}

data "openstack_images_image_v2" "ubuntu" {
  name        = var.image_name
  most_recent = true
}

resource "cloudflare_record" "domain" {
  count   = length([var.traefik_subdomain, var.docker_subdomain])
  zone_id = var.cloudflare_zone_id
  name    = [var.traefik_subdomain, var.docker_subdomain][count.index]
  content = openstack_networking_floatingip_v2.fip_1.address
  type    = "A"
  proxied = count.index == 0 ? true : false
}

data "openstack_networking_network_v2" "ext_network" {
  name = var.public_network
  external = true
}

data "openstack_networking_network_v2" "int_network" {
  name = var.cc_private_network
}

resource "openstack_networking_floatingip_v2" "fip_1" {
  pool = data.openstack_networking_network_v2.ext_network.name
}

resource "openstack_networking_floatingip_associate_v2" "fip_1" {
  floating_ip = openstack_networking_floatingip_v2.fip_1.address
  port_id     = openstack_networking_port_v2.registry.id
}

data "openstack_networking_secgroup_v2" "registry" {
  name = var.existing_secgroup_name
}

resource "openstack_networking_port_v2" "registry" {
  name               = "${var.project_name}-registry"
  admin_state_up     = "true"
  network_id         = data.openstack_networking_network_v2.int_network.id
  security_group_ids = [
    data.openstack_networking_secgroup_v2.registry.id
  ]
}


data "template_cloudinit_config" "registry_config" {
  part {
    filename     = "registry.yaml"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = data.template_file.registry_config.rendered
  }
}

data "template_file" "registry_config" {
  template = file("${path.module}/registry.yaml")
  vars = {
    use_existing_volume = var.existing_volume_uuid
    host_src_path = var.host_src_path
    docker_registry_user = var.docker_registry_user
    docker_registry_password = var.docker_registry_password
    volume_device  = var.existing_volume_uuid != "" ? "/dev/disk/by-uuid/${var.existing_volume_uuid}" : "/dev/disk/by-uuid/${openstack_blockstorage_volume_v3.registry_volume[0].id}"
    registry_local_volume = var.registry_local_volume
  }
}

data "template_file" "docker_compose" {
  template = file("${path.module}/templates/docker/registry/docker-compose.yaml")
  vars = {
    host_src_path = var.host_src_path
    registry_local_volume = var.registry_local_volume
    docker_subdomain = var.docker_subdomain
    server_domain = var.server_domain
  }
}

data "template_file" "redis_compose" {
  template = file("${path.module}/templates/docker/redis/docker-compose.yaml")
}

data "template_file" "traefik_compose" {
  template = file("${path.module}/templates/docker/traefik/docker-compose.yaml")
  vars = {
    host_src_path = var.host_src_path
    traefik_subdomain = var.traefik_subdomain
    server_domain = var.server_domain
  }
}


data "openstack_compute_keypair_v2" "registry" {
    name = var.existing_keypair_name
}

resource "openstack_blockstorage_volume_v3" "registry_volume" {
  count       = var.existing_volume_uuid == "" ? 1 : 0
  name        = "${var.project_name}-registry-volume"
  size        = var.instance_volume_size
  image_id    = data.openstack_images_image_v2.ubuntu.id
}

resource "openstack_compute_instance_v2" "registry" {
    name = "${var.project_name}_docker-registry"
    image_name = var.image_name
    flavor_name = var.flavor
    key_pair = data.openstack_compute_keypair_v2.registry.name
    user_data       = data.template_cloudinit_config.registry_config.rendered
    security_groups = [
        data.openstack_networking_secgroup_v2.registry.id
    ]
    network {
    port = openstack_networking_port_v2.registry.id
    }

    block_device {
    uuid                  = var.existing_volume_uuid != "" ? var.existing_volume_uuid : openstack_blockstorage_volume_v3.registry_volume[0].id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
  }
}

resource "terraform_data" "registry" {
    depends_on = [
        openstack_networking_floatingip_v2.fip_1
    ]

    connection {
        host = openstack_networking_floatingip_v2.fip_1.address
        user = var.ssh_user
    }

      provisioner "file" {
          content      = data.template_file.docker_compose.rendered
          destination = "${var.host_src_path}/docker-compose-registry.yaml"
      }

      provisioner "file" {
          content      = data.template_file.traefik_compose.rendered
          destination = "${var.host_src_path}/docker-compose-traefik.yaml"
      }

    provisioner "file" {
        content      = data.template_file.redis_compose.rendered
        destination = "${var.host_src_path}/docker-compose-redis.yaml"
    }


    provisioner "file" {
          source = "${path.module}/templates/docker/traefik/conf.d/traefik-dynamic.yaml"
          destination = "${var.host_src_path}/traefik-dynamic.yaml"
      }

    provisioner "remote-exec" {
        inline = [
            "echo 'Waiting for cloud-init to finish...'",
            "cloud-init status --wait >> /dev/null",
            "sudo mv ${var.host_src_path}/traefik-dynamic.yaml ${var.host_src_path}/traefik/conf.d/traefik-dynamic.yaml",
            "sudo docker network create --driver=overlay --attachable traefik-public",
            "sudo docker network create --driver=overlay --attachable traefik-external",
            "sudo mv ${var.host_src_path}/docker-compose-registry.yaml ${var.host_src_path}/registry/docker-compose.yaml",
            "sudo mv ${var.host_src_path}/docker-compose-traefik.yaml ${var.host_src_path}/traefik/docker-compose.yaml",
            "sudo mv ${var.host_src_path}/docker-compose-redis.yaml ${var.host_src_path}/redis/docker-compose.yaml",
            "cd ${var.host_src_path}/traefik",
            "sudo docker stack deploy -c docker-compose.yaml ${var.project_name}",
            "while [ -z \"$id\" ]; do",
            "  echo \"Waiting for nodes to join the swarm...\"",
            "  id=$(sudo docker node ls -q)",
            "  sleep 5",
            "done",
            "sudo docker node update --label-add traefik-public.traefik-public-certificates=true $id",
            "cd ${var.host_src_path}/redis",
            "sudo docker stack deploy -c docker-compose.yaml ${var.project_name}",
            "cd ${var.host_src_path}/registry",
            "sudo docker stack deploy -c docker-compose.yaml ${var.project_name}",
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