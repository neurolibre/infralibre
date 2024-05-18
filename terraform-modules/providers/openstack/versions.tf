
terraform {
  required_version = ">= 0.13"
  required_providers {
    openstack = {
      source = "terraform-providers/openstack"
    }
    template = {
      source = "hashicorp/template"
    }
  }
}
