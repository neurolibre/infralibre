terraform {
  required_version = ">= 0.14.0"
  required_providers {
    opennebula = {
      source  = "OpenNebula/opennebula"
      version = "~> 1.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2"
    }
  }
}