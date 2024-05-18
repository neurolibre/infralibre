
terraform {
  required_version = ">= 0.13"
  required_providers {
    openstack = {
      source = "terraform-providers/openstack"
      version = "<= 1.24.0"
    }
    template = {
      source = "hashicorp/template"
    }
  }
}
