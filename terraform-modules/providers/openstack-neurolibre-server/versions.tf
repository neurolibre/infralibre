
terraform {
  required_version = ">= 0.13"
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
      version = "~> 2.0.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    template = {
      source = "hashicorp/template"
    }
  }
}
