provider "kubectl" {
  host             = digitalocean_kubernetes_cluster.example.endpoint
  token            = digitalocean_kubernetes_cluster.example.kube_config[0].token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
  load_config_file       = false
}
