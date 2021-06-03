resource "kubernetes_namespace" "traefik" {
  metadata {
    annotations = {
      name = "traefik"
    }

    name = "traefik"
  }
}

resource "helm_release" "traefik" {
  name = "traefik"
  namespace = "traefik"
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
    namespace = "traefik"
  }

  data = {
    users = var.traefik_auth
  }

  type = "Opaque"
}

data "template_file" "traefik-ingres" {
  template = file("./kube_files/traefik/traefik-ingres.tmpl.yaml")
  vars = {
    dns_domain = var.dns_domain
    traefik_auth = var.traefik_auth
  }
}

resource "kubectl_manifest" "traefik-ingres" {
  override_namespace = "traefik"
  yaml_body = data.template_file.traefik-ingres.rendered
  depends_on = [
    kubernetes_namespace.traefik,
    helm_release.traefik,
    helm_release.cert-manager,
  ]
}
