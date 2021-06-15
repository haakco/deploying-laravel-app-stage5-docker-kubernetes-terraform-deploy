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

    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.11.1"
    }

    helm = {
      source = "hashicorp/helm"
      version = "~> 2.1"
    }
  }

  required_version = "~> 1.0.0"
}

