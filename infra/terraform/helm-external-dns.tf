locals {
  external_dns_name_space = "external-dns"
}

resource "kubernetes_namespace" "external-dns" {
  metadata {
    annotations = {
      name = local.external_dns_name_space
    }

    name = local.external_dns_name_space
  }
}

resource "kubernetes_secret" "external-dns-cloudflare-api-token" {
  metadata {
    name = "cloudflare-apikey"
    namespace = local.external_dns_name_space
  }

  data = {
    cloudflare_api_token = var.cloudflare_api_token
  }

  type = "Opaque"
  depends_on = [
    kubernetes_namespace.external-dns,
  ]
}

resource "helm_release" "external-dns" {
  name = "external-dns"
  namespace = local.external_dns_name_space
  repository = "https://charts.bitnami.com/bitnami"
  chart = "external-dns"
  version = "5.0.3"

//  values = [
//    data.template_file.prometheus_operator_values.rendered
//  ]

  set {
    name = "sources"
    value = "{service,ingress}"
  }

  set {
    name = "interval"
    value = "3m"
  }

  set {
    name = "registry"
//    value = "noop"
    value = "txt"
  }

  set {
    name = "txtOwnerId"
    value = "lvexample"
  }

  set {
    name = "txtPrefix"
    value = "lvexample."
  }

  set {
    name = "provider"
    value = "cloudflare"
  }

  set {
    name = "cloudflare.secretName"
    value = "cloudflare-apikey"
  }

  set {
    name = "domainFilters"
    value = "{${var.dns_domain}}"
  }

  set {
    name = "cloudflare.proxied"
    value = "false"
  }

  set {
    name = "metrics.enabled"
    value = "true"
  }

  set {
    name = "policy"
    value = "sync"
  }

  set {
    name = "rbac.create"
    value = "true"
  }

  set {
    name = "rbac.clusterRole"
    value = "true"
  }

  set {
    name = "logLevel"
//    value = "info"
    value = "debug"
  }

  depends_on = [
    kubernetes_secret.external-dns-cloudflare-api-token,
    kubernetes_namespace.external-dns,
  ]
}
