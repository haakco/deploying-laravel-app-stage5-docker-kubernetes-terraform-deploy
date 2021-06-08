locals {
  traefik_name_space = "traefik"
}

resource "kubernetes_namespace" "traefik" {
  metadata {
    annotations = {
      name = local.traefik_name_space
    }
    name = local.traefik_name_space
  }
}

resource "helm_release" "traefik" {
  name = "traefik"
  namespace = local.traefik_name_space
  repository = "https://containous.github.io/traefik-helm-chart"
  chart = "traefik"
  version = "9.1.1"

  values = [
    file("./kube_files/traefik/traefik-values.yaml")
  ]

  depends_on = [
    kubernetes_namespace.traefik,
  ]
}

resource "kubernetes_secret" "traefik_auth" {
  metadata {
    name = "traefik-authsecret"
    namespace = local.traefik_name_space
  }

  data = {
    users = var.traefik_auth
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace.traefik,
  ]
}

resource "kubernetes_service" "traefik-web-ui" {
  metadata {
    name = "traefik-web-ui"
    namespace = local.traefik_name_space
  }
  spec {
    selector = {
      "app.kubernetes.io/instance" = "traefik"
      "app.kubernetes.io/instance" = "traefik"
    }
    port {
      name = "web"
      port = 9000
      target_port = 9000
    }
  }

  depends_on = [
    kubernetes_namespace.traefik,
    helm_release.traefik,
  ]
}

resource "kubectl_manifest" "traefik-middleware-auth" {
  override_namespace = local.traefik_name_space
  yaml_body = file("./kube_files/traefik/traefik-middleware-auth.yaml")
  depends_on = [
    kubernetes_namespace.traefik,
    helm_release.traefik,
    kubernetes_secret.traefik_auth,
  ]
}

resource "kubectl_manifest" "traefik-middleware-compress" {
  override_namespace = local.traefik_name_space
  yaml_body = file("./kube_files/traefik/traefik-middleware-compress.yaml")
  depends_on = [
    kubernetes_namespace.traefik,
    helm_release.traefik,
  ]
}

resource "kubernetes_ingress" "traefik-ingres" {
  metadata {
    name = "traefik"
    namespace = local.traefik_name_space
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls" = "true"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-traefik-compress@kubernetescrd,traefik-traefik-auth@kubernetescrd"
      "cert-manager.io/cluster-issuer" = "letsencrypt-dns-production"
      "external-dns.alpha.kubernetes.io/hostname" = "traefik.${var.dns_domain}"
    }
  }

  spec {
    rule {
      host = "traefik.${var.dns_domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "traefik-web-ui"
            service_port = 9000
          }
        }
      }
    }
    tls {
      hosts = [
        "traefik.${var.dns_domain}"
      ]
      secret_name = "traefik-cert-tls"
    }
  }
  depends_on = [
    kubernetes_namespace.traefik,
    kubectl_manifest.traefik-middleware-auth,
    kubectl_manifest.traefik-middleware-compress,
    helm_release.cert-manager,
    helm_release.traefik,
  ]
}
