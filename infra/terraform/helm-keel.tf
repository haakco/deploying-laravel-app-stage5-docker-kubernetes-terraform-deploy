locals {
  keel_name_space = "keel"
}

resource "kubernetes_namespace" "keel" {
  metadata {
    annotations = {
      name = local.keel_name_space
    }
    name = local.keel_name_space
  }
}

data "template_file" "keel_values" {
  template = file("./kube_files/keel/keel-values.tmpl.yml")
  vars = {
    traefik_username = var.traefik_username
    traefik_password = var.traefik_password
  }
}

resource "helm_release" "keel" {
  name = "keel"
  namespace = local.keel_name_space
  repository = "https://charts.keel.sh"
  chart = "keel"
  version = "0.9.8"
  values = [
    data.template_file.keel_values.rendered
  ]

  depends_on = [
    kubernetes_namespace.keel,
  ]
}

resource "kubernetes_ingress" "keel-ingres" {
  metadata {
    name = "keel"
    namespace = local.keel_name_space
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls" = "true"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-traefik-compress@kubernetescrd,traefik-traefik-auth@kubernetescrd"
      "cert-manager.io/cluster-issuer" = "letsencrypt-production"
      "external-dns.alpha.kubernetes.io/hostname" = "keel.${var.dns_domain}"
    }
  }

  spec {
    rule {
      host = "keel.${var.dns_domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "keel"
            service_port = 9300
          }
        }
      }
    }
    tls {
      hosts = [
        "keel.${var.dns_domain}"
      ]
      secret_name = "keel-cert-tls"
    }
  }
  depends_on = [
    kubernetes_namespace.keel,
    kubectl_manifest.traefik-middleware-auth,
    kubectl_manifest.traefik-middleware-compress,
    helm_release.cert-manager,
    helm_release.traefik,
    helm_release.keel,
  ]
}
