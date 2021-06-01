terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 2.21"
    }

    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.9"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.2"
    }

    helm = {
      source = "hashicorp/helm"
      version = "~> 2.1"
    }
  }

  required_version = "~> 0.15"
}

