locals {
  cert_manager_name_space = "cert-manager"
}

locals {
  cert_email = "cert@${var.dns_domain}"
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
    helm_release.cert-manager,
  ]
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

  depends_on = [
    kubernetes_namespace.cert-manager,
    helm_release.prometheus-operator,
  ]
}

data "template_file" "acme_dns_production" {
  template = file("./kube_files/cert/acme-dns-production.tmpl.yaml")
  vars = {
    cert_email = local.cert_email
  }
}

resource "kubectl_manifest" "acme-dns-prod-config" {
  override_namespace = local.cert_manager_name_space
  yaml_body = data.template_file.acme_dns_production.rendered
  depends_on = [
    kubernetes_namespace.cert-manager,
    helm_release.cert-manager,
    kubernetes_secret.cert-manager-cloudflare-api-token,
  ]
}

data "template_file" "acme_dns_staging" {
  template = file("./kube_files/cert/acme-dns-staging.tmpl.yaml")
  vars = {
    cert_email = local.cert_email
  }
}

resource "kubectl_manifest" "acme_dns_staging_config" {
  override_namespace = local.cert_manager_name_space
  yaml_body = data.template_file.acme_dns_staging.rendered
  depends_on = [
    kubernetes_namespace.cert-manager,
    helm_release.cert-manager,
    kubernetes_secret.cert-manager-cloudflare-api-token,
  ]
}
