terraform {
  required_providers {

    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.9"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.3"
    }

    kubectl = {
      source = "gavinbunney/kubectl"
      version = "~> 1.11"
    }

    helm = {
      source = "hashicorp/helm"
      version = "~> 2.2"
    }
  }

  required_version = "~> 1.0.0"
}

