locals {
  elastic_name_space = "elastic"
}

resource "kubernetes_namespace" "elastic" {
  metadata {
    annotations = {
      name = local.elastic_name_space
    }
    name = local.elastic_name_space
  }
}

resource "helm_release" "elastic" {
  name = "elasticsearch"
  namespace = local.elastic_name_space
  repository = "https://helm.elastic.co"
  chart = "elasticsearch"
  version = "7.13.1"

  values = [
    file("./kube_files/elastic/elasticsearch-values.yaml")
  ]

  depends_on = [
    kubernetes_namespace.elastic,
  ]
}

resource "helm_release" "kibana" {
  name = "kibana"
  namespace = local.elastic_name_space
  repository = "https://helm.elastic.co"
  chart = "kibana"
  version = "7.13.1"

  set {
    name = "replicas"
    value = "1"
  }
  set {
    name = "ingress.enabled"
    value = "false"
  }

  depends_on = [
    kubernetes_namespace.elastic,
    helm_release.elastic,
  ]
}

resource "kubernetes_ingress" "elastic-ingres" {
  metadata {
    name = "kibana"
    namespace = local.elastic_name_space
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls" = "true"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-traefik-compress@kubernetescrd,traefik-traefik-auth@kubernetescrd"
      "cert-manager.io/cluster-issuer" = "letsencrypt-dns-production"
      "external-dns.alpha.kubernetes.io/hostname" = "kibana.${var.dns_domain}"
    }
  }

  spec {
    rule {
      host = "kibana.${var.dns_domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "kibana-kibana"
            service_port = 5601
          }
        }
      }
    }
    tls {
      hosts = [
        "kibana.${var.dns_domain}"
      ]
      secret_name = "kibana-cert-tls"
    }
  }
  depends_on = [
    kubectl_manifest.traefik-middleware-auth,
    kubectl_manifest.traefik-middleware-compress,
    helm_release.cert-manager,
    helm_release.traefik,
    helm_release.elastic,
  ]
}

resource "helm_release" "metricbeat" {
  name = "metricbeat"
  namespace = local.elastic_name_space
  repository = "https://helm.elastic.co"
  chart = "metricbeat"
  version = "7.13.1"
  depends_on = [
    kubernetes_namespace.elastic,
    helm_release.elastic,
  ]
}

resource "helm_release" "filebeat" {
  name = "filebeat"
  namespace = local.elastic_name_space
  repository = "https://helm.elastic.co"
  chart = "filebeat"
  version = "7.13.1"
  values = [
    file("./kube_files/elastic/filebeat-values.yaml")
  ]
  depends_on = [
    kubernetes_namespace.elastic,
    helm_release.elastic,
  ]
}
