resource "digitalocean_kubernetes_cluster" "example" {
  name    = var.kubernetes_cluster_name
  region  = var.region
  version = var.kubernetes_version
  auto_upgrade = var.kubernetes_auto_upgrade
  surge_upgrade = var.kubernetes_surge_upgrade

  node_pool {
    name       = var.kubernetes_cluster_autoscale_pool_name
    size       = var.server_size
    auto_scale = var.kubernetes_auto_scale
    min_nodes  = var.kubernetes_min_nodes
    max_nodes  = var.kubernetes_max_nodes
    node_count = var.kubernetes_default_nodes
  }
}
