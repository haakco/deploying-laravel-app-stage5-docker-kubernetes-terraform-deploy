resource "kubernetes_namespace" "monitoring" {
  metadata {
    annotations = {
      name = "monitoring"
    }

    name = "monitoring"
  }
}

data "template_file" "prometheus_operator_values" {
  template = file("./templates/prometheus/prometheus-values.tmpl.yaml")
  vars = {
    grafana_admin_password = var.grafana_admin_password
    dns_domain = var.dns_domain
  }
}

resource "helm_release" "prometheus-operator" {
  name = "prometheus-operator"
  namespace = "monitoring"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart = "kube-prometheus-stack"
  version = "16.1.0"

  values = [
    data.template_file.prometheus_operator_values.rendered
  ]
}
