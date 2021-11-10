module "provider" {
  source = "git::ssh://git@github.com/cmd-ntrf/terraform-binderhub.git//terraform-modules/providers/openstack"

  project_name         = "ccbinder"
  nb_nodes             = 1
  instance_volume_size = 20
  ssh_authorized_keys  = [""]
  os_flavor_master     = "p2-3gb"
  os_flavor_node       = "p2-3gb"
  image_name           = "Ubuntu-16.04.2-Xenial-x64-2017-07"
  is_computecanada     = true
}

module "dns" {
  source = "git::ssh://git@github.com/cmd-ntrf/terraform-binderhub.git//terraform-modules/dns/cloudflare"

  domain    = "mydomainname.com"
  public_ip = "${module.provider.public_ip}"
}

module "binderhub" {
  source = "git::ssh://git@github.com/cmd-ntrf/terraform-binderhub.git//terraform-modules/binderhub"

  ip               = "${module.provider.public_ip}"
  domain           = "${module.dns.domain}"
  admin_user       = "${module.provider.admin_user}"
  binder_version   = "v0.2.0-58e8ae9"
  TLS_email        = "email@example.ca"
  mem_alloc_gb     = 1.5
  cpu_alloc        = 1
  docker_id        = ""
  docker_password  = ""
}
