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
