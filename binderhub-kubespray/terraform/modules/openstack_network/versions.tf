terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
      version = "~> 1.51.1"
    }
  }
  required_version = ">= 1.8.0"
}