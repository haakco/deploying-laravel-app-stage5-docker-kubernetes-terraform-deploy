variable kubernetes_default_nodes {
  default = 3
}

variable kubernetes_min_nodes {
  default = 1
}

variable kubernetes_max_nodes {
  default = 5
}

variable server_size {
  default = "s-2vcpu-4gb"
  //    default = "s-4vcpu-8gb"
}

variable kubernetes_version {
  default = "1.20.7-do.0"
}

variable kubernetes_auto_upgrade {
  default = true
}

variable kubernetes_cluster_name {
  default = "example"
}

variable kubernetes_cluster_autoscale_pool_name {
  default = "autoscale-worker-pool"
}

variable kubernetes_auto_scale {
  default = true
}

variable kubernetes_surge_upgrade {
  default = true
}
