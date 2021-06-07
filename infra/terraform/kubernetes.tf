//#===K8TESTCLUSTER KUBERNETES===============================================
provider "kubernetes" {
  host             = digitalocean_kubernetes_cluster.example.endpoint
  token            = digitalocean_kubernetes_cluster.example.kube_config[0].token

  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
}

#---GENERIC/DASHBOARD USER-------------------------------------------------
# This account has the token we use to get into the dashboard using its permissions
resource "kubernetes_service_account" "dashboard-admin" {
  automount_service_account_token = true

  metadata {
    name      = "dashboard-admin-sa"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "dashboard-admin-clusterrolebinding" {
  metadata {
    name = "dashboard-admin-rb"
  }
  role_ref {
    kind      = "ClusterRole"
    name      = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "User"
    name      = "dashboard-admin"
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "dashboard-admin-sa"
    namespace = "kube-system"
  }
  subject {
    kind      = "Group"
    name      = "system:masters"
    api_group = "rbac.authorization.k8s.io"
  }
}
