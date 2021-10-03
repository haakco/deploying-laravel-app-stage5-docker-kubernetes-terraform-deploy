data "digitalocean_kubernetes_versions" "example" {
  version_prefix = var.kubernetes_version_prefix
}

resource "digitalocean_kubernetes_cluster" "example" {
  name    = var.kubernetes_cluster_name
  region  = var.region
  version = data.digitalocean_kubernetes_versions.example.latest_version
  auto_upgrade = var.kubernetes_auto_upgrade
  surge_upgrade = var.kubernetes_surge_upgrade

  maintenance_policy {
    start_time  = "04:00"
    day         = "sunday"
  }

  node_pool {
    name       = var.kubernetes_cluster_autoscale_pool_name
    size       = var.server_size
    auto_scale = var.kubernetes_auto_scale
    min_nodes  = var.kubernetes_min_nodes
    max_nodes  = var.kubernetes_max_nodes
    node_count = var.kubernetes_default_nodes
  }
}
