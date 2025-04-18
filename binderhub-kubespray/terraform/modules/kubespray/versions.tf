terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
      version = "~> 2.4.0"
    }
    external = {
      source = "hashicorp/external"
      version = "~> 2.3.0"
    }
  }
  required_version = ">= 1.8.0"
}