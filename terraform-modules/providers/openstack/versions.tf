
terraform {
  required_version = ">= 0.13"
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
      version = "<= 1.24.0"
    }
    template = {
      source = "hashicorp/template"
    }
  }
}
