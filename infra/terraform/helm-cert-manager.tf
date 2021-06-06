locals {
  cert_manager_name_space = "cert-manager"
}

resource "kubernetes_namespace" "cert-manager" {
  metadata {
    annotations = {
      name = local.cert_manager_name_space
    }

    labels = {
      "certmanager.k8s.io/disable-validation" = "true"
    }

    name = local.cert_manager_name_space
  }
}

resource "helm_release" "cert-manager" {
  name = "cert-manager"
  namespace = local.cert_manager_name_space
  repository = "https://charts.jetstack.io"
  chart = "cert-manager"
  version = "1.3.1"

  set {
    name = "installCRDs"
    value = "true"
  }

  set {
    name = "prometheus.enabled"
    value = "true"
  }

  set {
    name = "prometheus.servicemonprometheus-values.env.yamlitor.enabled"
    value = "true"
  }

  depends_on = [
    kubernetes_namespace.cert-manager,
    helm_release.prometheus-operator,
  ]
}

resource "kubernetes_secret" "cert-manager-cloudflare-api-token" {
  metadata {
    name = "cloudflare-apikey"
    namespace = local.cert_manager_name_space
  }

  data = {
    cloudflare_api_token = var.cloudflare_api_token
  }

  type = "Opaque"
  depends_on = [
    kubernetes_namespace.cert-manager,
  ]
}

resource "kubectl_manifest" "acme-prod-config" {
  override_namespace = local.cert_manager_name_space
  yaml_body = file("./kube_files/cert/acme-production.yaml")
  depends_on = [
    kubernetes_namespace.cert-manager,
    helm_release.cert-manager,
    kubernetes_secret.cert-manager-cloudflare-api-token,
  ]
}

resource "kubectl_manifest" "acme-staging-config" {
  override_namespace = local.cert_manager_name_space
  yaml_body = file("./kube_files/cert/acme-staging.yaml")
  depends_on = [
    kubernetes_namespace.cert-manager,
    helm_release.cert-manager,
    kubernetes_secret.cert-manager-cloudflare-api-token,
  ]
}
