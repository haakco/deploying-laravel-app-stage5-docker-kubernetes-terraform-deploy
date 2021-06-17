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

resource "helm_release" "kubernetes-dashboard" {
  name = "kubernetes-dashboard"
  namespace = "kube-system"
  repository = "https://kubernetes.github.io/dashboard"
  chart = "kubernetes-dashboard"
  version = "4.2.0"
  set {
    name  = "metricsScraper.enabled"
    value = "true"
  }
  set {
    name  = "metrics-server.enabled"
    value = "true"
  }
  set {
    name  = "metrics-server.args"
    value = "{--kubelet-preferred-address-types=InternalIP}"
  }
}
