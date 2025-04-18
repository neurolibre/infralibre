terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
      version = "~> 1.51.1"
    }
    local = {
      source = "hashicorp/local"
      version = "~> 2.4.0"
    }
    template = {
      source = "hashicorp/template"
      version = "~> 2.2.0"
    }
  }
  required_version = ">= 1.8.0"
}