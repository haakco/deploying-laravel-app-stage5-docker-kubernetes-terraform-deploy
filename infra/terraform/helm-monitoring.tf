resource "kubernetes_namespace" "monitoring" {
  metadata {
    annotations = {
      name = "monitoring"
    }

    name = "monitoring"
  }
}

data "template_file" "prometheus_operator_values" {
  template = file("./kube_files/monitoring/prometheus-values.tmpl.yaml")
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

  depends_on = [
    kubernetes_namespace.monitoring,
  ]
}

resource "kubernetes_ingress" "prometheus-ingres" {
  metadata {
    name = "prometheus"
    namespace = "monitoring"
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls" = "true"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-traefik-compress@kubernetescrd,traefik-traefik-auth@kubernetescrd"
      "cert-manager.io/cluster-issuer" = "letsencrypt-production"
      "external-dns.alpha.kubernetes.io/hostname" = "prometheus.${var.dns_domain}, alertmanager.${var.dns_domain}"
    }
  }

  spec {
    rule {
      host = "prometheus.${var.dns_domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "prometheus-operated"
            service_port = 9090
          }
        }
      }
    }
    rule {
      host = "alertmanager.${var.dns_domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "alertmanager-operated"
            service_port = 9093
          }
        }
      }
    }
    tls {
      hosts = [
        "prometheus.${var.dns_domain}",
        "alertmanager.${var.dns_domain}"
      ]
      secret_name = "prometheus-cert-tls"
    }
  }
  depends_on = [
    kubernetes_namespace.monitoring,
    kubectl_manifest.traefik-middleware-auth,
    kubectl_manifest.traefik-middleware-compress,
    helm_release.cert-manager,
    helm_release.traefik,
  ]
}

resource "kubernetes_ingress" "grafana-ingres" {
  metadata {
    name = "grafana"
    namespace = "monitoring"
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls" = "true"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-traefik-compress@kubernetescrd"
      "cert-manager.io/cluster-issuer" = "letsencrypt-production"
      "external-dns.alpha.kubernetes.io/hostname" = "grafana.${var.dns_domain}"
    }
  }

  spec {
    rule {
      host = "grafana.${var.dns_domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "prometheus-operator-grafana"
            service_port = 80
          }
        }
      }
    }
    tls {
      hosts = [
        "grafana.${var.dns_domain}"
      ]
      secret_name = "grafana-cert-tls"
    }
  }
  depends_on = [
    kubernetes_namespace.monitoring,
    kubectl_manifest.traefik-middleware-auth,
    kubectl_manifest.traefik-middleware-compress,
    helm_release.cert-manager,
    helm_release.traefik,
  ]
}
