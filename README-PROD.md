## Production setup

We'll next cover the production setup.

For this we'll be using Digital Oceans kubernetes.

We'll set this up via Terraform and then do systems helm setup via Terraform as well.

### Terraform

I've tried to make most the tunable or things like token into variables.

These can be found in these files.

* [./infra/terraform/variables.tf](./infra/terraform/variables.tf)
* [./infra/terraform/variables_dns.tf](./infra/terraform/variables_dns.tf)
* [./infra/terraform/variables_certs.tf](./infra/terraform/variables_certs.tf)
* [./infra/terraform/variables_helm.tf](./infra/terraform/variables_helm.tf)
* [./infra/terraform/variables_kubernetes.tf](./infra/terraform/variables_kubernetes.tf)
* [./infra/terraform/variables_wave.tf](./infra/terraform/variables_wave.tf)

#### Terraform Versions

We start by specifying all the versions of the plugins we will be using.
[./infra/terraform/versions.tf](./infra/terraform/versions.tf)
```hcl
terraform {
  required_providers {

    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.9"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.2"
    }

    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.11.1"
    }

    helm = {
      source = "hashicorp/helm"
      version = "~> 2.1"
    }
  }

  required_version = "~> 1.0.0"
}
```

#### Create Kubernetes Cluster

Next we want to set up the kubernetes cluster.

We'll be using the [DigtalOcean provider](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs)

First we log in to the provider with the DigitalOcean token.

[./infra/terraform/do_account.tf](./infra/terraform/do_account.tf)
```hcl
provider "digitalocean" {
  token = var.do_token
}
```

Next we create the kubernetes cluster.

[./infra/terraform/do_kubernetes.tf](./infra/terraform/do_kubernetes.tf)
```hcl
resource "digitalocean_kubernetes_cluster" "example" {
  name    = var.kubernetes_cluster_name
  region  = var.region
  version = var.kubernetes_version
  auto_upgrade = var.kubernetes_auto_upgrade
  surge_upgrade = var.kubernetes_surge_upgrade

  node_pool {
    name       = var.kubernetes_cluster_autoscale_pool_name
    size       = var.server_size
    auto_scale = var.kubernetes_auto_scale
    min_nodes  = var.kubernetes_min_nodes
    max_nodes  = var.kubernetes_max_nodes
    node_count = var.kubernetes_default_nodes
  }
}
```

#### Setup Kubernetes

We then use the [Kubernetes provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs).

First we tell the provider how to access the cluster using the setting generated while creating
the cluster.

[./infra/terraform/kubernetes.tf](./infra/terraform/kubernetes.tf)
```hcl
provider "kubernetes" {
  host             = digitalocean_kubernetes_cluster.example.endpoint
  token            = digitalocean_kubernetes_cluster.example.kube_config[0].token

  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
}
```

#### Setup Kubectl

The Hashicorp Kubernetes provider only covers the standard kubernetes resources.

So to hands any others we are using the [Kubectl provider](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs).

This allows us to apply standard Yaml files for anything not covered.

The configuration is very similar.

[./infra/terraform/kubectl.tf](./infra/terraform/kubectl.tf)
```hcl
provider "kubectl" {
  host             = digitalocean_kubernetes_cluster.example.endpoint
  token            = digitalocean_kubernetes_cluster.example.kube_config[0].token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
  load_config_file       = false
}
```

#### Setup Helm

We also then set up the [Helm provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)

[./infra/terraform/helm.tf](./infra/terraform/helm.tf)
```hcl
provider "helm" {
  kubernetes {
    host = digitalocean_kubernetes_cluster.example.endpoint
    token = digitalocean_kubernetes_cluster.example.kube_config[0].token

    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
  }
}
```

#### Setup Helm Dashboard

[./infra/terraform/helm-dashboard.tf](./infra/terraform/helm-dashboard.tf)
```hcl
resource "kubernetes_service_account" "dashboard-admin" {
  automount_service_account_token = true

  metadata {
    name      = "dashboard-admin-sa"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "dashboard-admin-clusterrolebinding" {
  metadata {
    name = "dashboard-admin-rb"
  }
  role_ref {
    kind      = "ClusterRole"
    name      = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "User"
    name      = "dashboard-admin"
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "dashboard-admin-sa"
    namespace = "kube-system"
  }
  subject {
    kind      = "Group"
    name      = "system:masters"
    api_group = "rbac.authorization.k8s.io"
  }
}

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
```

You'll see as we did for local we fist create a service account and and give it the correct roles.

We then do a helm install of the dashboard.

If you compare it to the helm install for the previous version you'll see that they match quiet
closely.

#### Setup Helm Monitoring

[./infra/terraform/helm-dashboard.tf](./infra/terraform/helm-monitoring.tf)
```hcl
locals {
  monitoring_name_space = "monitoring"
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    annotations = {
      name = local.monitoring_name_space
    }
    name = local.monitoring_name_space
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
  namespace = local.monitoring_name_space
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
    namespace = local.monitoring_name_space
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls" = "true"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-traefik-compress@kubernetescrd,traefik-traefik-auth@kubernetescrd"
      "cert-manager.io/cluster-issuer" = "letsencrypt-dns-production"
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
    namespace = local.monitoring_name_space
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls" = "true"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-traefik-compress@kubernetescrd"
      "cert-manager.io/cluster-issuer" = "letsencrypt-dns-production"
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
```

We also follow a similar proces to what we did for the local development enviroment.

We first create the namespace.

Next we create the values files via ```template_file```. Previously we did this with envsubst.

We then install the ```prometheus-operator``` helm chart. You'll also notice we use the ```depends_on```
To ensure its only run after the namespace is created.

Next we add the ingres routes for the ```prometheus-operator``` endpoints.

Though be aware these require that you have Traefik activated before they can run. To get around
this we also use the ```depends_on``` to say we need the helm traefik chart to be installed
before running this.

You'll see this points the ```helm_release.traefik``` which we cover in the Traefik helm file.

#### Setup Helm ExternalDns

[./infra/terraform/helm-external-dns.tf](./infra/terraform/helm-external-dns.tf)
```hcl
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
```

For local, we didn't add [ExternalDns](https://github.com/kubernetes-sigs/external-dns).

Else every user spinning up a enviroment would have been adding DNS entries.

So we just did the wild card entry pointing at ```127.0.0.1```.

We are now setting up production it makes our life easier to set up ExternalDNS.

This will automatically add DNS entries from our ingres routes pointing at the external IP of
the cluster.

Looking at the HCL config you'll see it follows similar steps to most of the installations.

We first create a namespace.

Then we add the Cloudflare api token as a secret. This is the same as for CertManager.

We then install the ExternalDns helm chart.

Providing its configuration. Things like that we are using CloudFlare and where to find the secret.

#### Setup Helm CertManager

[./infra/terraform/helm-cert-manager.tf](./infra/terraform/helm-cert-manager.tf)
```hcl
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
```

Next we install CertManager. Following the same pattern as the previous installs.

#### Setup Helm Traefik

[./infra/terraform/helm-traefik.tf](./infra/terraform/helm-traefik.tf)
```hcl
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
```

The main difference with this install to the previous one is the ```external-dns.alpha.kubernetes.io/hostname```
annotation. This is how we let ExternalDNS know which DNS entries to add.

#### Setup Helm Keel

[./infra/terraform/helm-keel.tf](./infra/terraform/helm-keel.tf)
```hcl
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
      "cert-manager.io/cluster-issuer" = "letsencrypt-dns-production"
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
```

#### Setup Helm Keel

[./infra/terraform/helm-elastic.tf](./infra/terraform/helm-elastic.tf)
```hcl
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
```

As we will be running multiple versions of our Laravel application, it becomes harder to watch
the logs of every container.

So we are adding the ELK stack and piping all logs from Kubernetes to it.

#### Setup Laravel Application

Now that we have once again set up the enviroment.

We'll do the deployment of the Laravel Applications.

```hcl
locals {
  wave_name_space = "wave"
}

resource "kubernetes_namespace" "wave_name_space" {
  metadata {
    annotations = {
      name = local.wave_name_space
    }

    name = local.wave_name_space
  }
}

resource "kubernetes_secret" "wave_docker_registry_login" {
  metadata {
    name = "docker-registry-credential"
  }

  data = {
    ".dockerconfigjson" = <<DOCKER
{
  "auths": {
    "${var.wave_registry_server}": {
      "auth": "${base64encode("${var.wave_registry_username}:${var.wave_registry_password}")}"
    }
  }
}
DOCKER
  }

  type = "kubernetes.io/dockerconfigjson"
  depends_on = [
    kubernetes_namespace.wave_name_space,
  ]
}

resource "kubernetes_secret" "wave-secrets" {
  metadata {
    name = "wave-secrets"
    namespace = local.wave_name_space
  }

  data = {
    "postgresql-password" = var.wave_db_password
    "redis-password" = var.wave_redis_password
    "wave_app_mail_password" = var.wave_app_mail_password
    "wave_app_jwt_secret" = var.wave_app_jwt_secret
    "wave_app_key" = var.wave_app_key
  }

  type = "Opaque"
  depends_on = [
    kubernetes_namespace.wave_name_space,
  ]
}

data "template_file" "wave_postgres" {
  template = file("./kube_files/wave/postgresql-values.tmpl.yaml")
  vars = {
    wave_db_replica_count = var.wave_db_replica_count
    wave_db_name = var.wave_db_name
    wave_db_user = var.wave_db_user
    wave_db_password = var.wave_db_password
    wave_db_repmgr_password = var.wave_db_password
    wave_db_pgpool_admin_password = var.wave_db_password
  }
}

resource "helm_release" "wave-postgresql-ha" {
  name = "postgresql-ha"
  namespace = local.wave_name_space
  repository = "https://charts.bitnami.com/bitnami"
  chart = "postgresql-ha"
  version = "7.6.0"

  values = [
    data.template_file.wave_postgres.rendered
  ]

  depends_on = [
    kubernetes_namespace.wave_name_space,
    kubernetes_secret.wave-secrets,
    helm_release.elastic,
  ]
}

data "template_file" "wave_redis" {
  template = file("./kube_files/wave/redis-values.tmp.yaml")
  vars = {
    wave_redis_replica_count = var.wave_redis_replica_count
  }
}

resource "helm_release" "wave-redis" {
  name = "redis"
  namespace = local.wave_name_space
  repository = "https://charts.bitnami.com/bitnami"
  chart = "redis"
  version = "14.3.3"

  values = [
    data.template_file.wave_redis.rendered
  ]

  depends_on = [
    kubernetes_namespace.wave_name_space,
    kubernetes_secret.wave-secrets,
    helm_release.elastic,
  ]
}

resource "kubernetes_deployment" "wave-lv-example" {
  metadata {
    name = "wave-lv-example"
    namespace = local.wave_name_space
    annotations = {
      "keel.sh/policy": "force"
      "keel.sh/trigger": "poll"
      "keel.sh/pollSchedule": "@every 5m"
    }
  }
  spec {
    replicas = var.wave_app_replicas

    selector {
      match_labels = {
        "app" = "wave-lv-example"
      }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge = "1"
        max_unavailable = "50%"
      }
    }

    template {
      metadata {
        labels = {
          app = "wave-lv-example"
        }
        annotations = {
          "co.elastic.logs/enabled" = "true"
          "co.elastic.logs/json.keys_under_root" = "true"
          "co.elastic.logs/json.message_key" = "message"
          "co.elastic.logs/json.overwrite_keys" = "true"
        }
      }

      spec {
        image_pull_secrets {
          name = "docker-registry-credential"
        }
        container {
          image = "haakco/deploying-laravel-app-ubuntu-20.04-php7.4-lv-wave:latest"
          name = "wave-lv-example"

          port {
            container_port = 80
          }
          env {
            name = "LVENV_JWT_SECRET"
            value_from {
              secret_key_ref {
                name = "wave-secrets"
                key = "wave_app_jwt_secret"
              }
            }
          }
          env {
            name = "LVENV_APP_KEY"
            value_from {
              secret_key_ref {
                name = "wave-secrets"
                key = "wave_app_key"
              }
            }
          }
          env {
            name = "LVENV_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = "wave-secrets"
                key = "postgresql-password"
              }
            }
          }
          env {
            name = "LVENV_REDIS_PASSWORD"

            value_from {
              secret_key_ref {
                name = "wave-secrets"
                key = "redis-password"
              }
            }
          }
          env {
            name = "LVENV_MAIL_PASSWORD"
            value_from {
              secret_key_ref {
                name = "wave-secrets"
                key = "wave_app_mail_password"
              }
            }
          }

          env {
            name = "ENABLE_HORIZON"
            value = "FALSE"
          }

          env {
            name = "CRONTAB_ACTIVE"
            value = "TRUE"
          }

          env {
            name = "GEN_LV_ENV"
            value = "TRUE"
          }
          env {
            name = "LVENV_APP_NAME"
            value = var.wave_app_name
          }
          env {
            name = "LVENV_APP_ENV"
            value = var.wave_app_name_env
          }
          env {
            name = "LVENV_APP_DEBUG"
            value = var.wave_app_debug
          }
          env {
            name = "LVENV_APP_LOG_LEVEL"
            value = var.wave_app_log_level
          }
          env {
            name = "LVENV_APP_URL"
            value = "https://${var.dns_domain}"
          }
          env {
            name = "LVENV_DB_CONNECTION"
            value = "pgsql"
          }
          env {
            name = "LVENV_DB_HOST"
            value = "postgresql-ha-pgpool.wave.svc.cluster.local"
          }
          env {
            name = "LVENV_DB_PORT"
            value = "5432"
          }
          env {
            name = "LVENV_DB_DATABASE"
            value = var.wave_db_name
          }
          env {
            name = "LVENV_DB_USERNAME"
            value = var.wave_db_user
          }
          env {
            name = "LVENV_BROADCAST_DRIVER"
            value = "log"
          }
          env {
            name = "LVENV_CACHE_DRIVER"
            value = "redis"
          }
          env {
            name = "LVENV_SESSION_DRIVER"
            value = "redis"
          }
          env {
            name = "LVENV_SESSION_LIFETIME"
            value = "9999"
          }
          env {
            name = "LVENV_QUEUE_DRIVER"
            value = "redis"
          }
          env {
            name = "LVENV_REDIS_HOST"
            value = "redis-master.wave.svc.cluster.local"
          }
          env {
            name = "LVENV_REDIS_PORT"
            value = "6379"
          }
          env {
            name = "LVENV_MAIL_DRIVER"
            value = "smtp"
          }
          env {
            name = "LVENV_MAIL_HOST"
            value = var.wave_app_mail_host
          }
          env {
            name = "LVENV_MAIL_PORT"
            value = var.wave_app_mail_port
          }
          env {
            name = "LVENV_MAIL_USERNAME"
            value = var.wave_app_mail_username
          }
          env {
            name = "LVENV_MAIL_ENCRYPTION"
            value = var.wave_app_mail_encryption
          }
          env {
            name = "LVENV_PUSHER_APP_ID"
            value = ""
          }
          env {
            name = "LVENV_PUSHER_APP_KEY"
            value = ""
          }
          env {
            name = "LVENV_PUSHER_APP_SECRET"
            value = ""
          }
          env {
            name = "LVENV_REDIS_CLIENT"
            value = "phpredis"
          }
          env {
            name = "LVENV_PADDLE_VENDOR_ID"
            value = ""
          }
          env {
            name = "LVENV_PADDLE_VENDOR_AUTH_CODE"
            value = ""
          }
          env {
            name = "LVENV_PADDLE_ENV"
            value = "sandbox"
          }
          env {
            name = "LVENV_WAVE_DOCS"
            value = "true"
          }
          env {
            name = "LVENV_WAVE_DEMO"
            value = "true"
          }
          env {
            name = "LVENV_WAVE_BAR"
            value = "true"
          }
          env {
            name = "LVENV_TRUSTED_PROXIES"
            value = var.wave_app_trusted_proxies
          }
          env {
            name = "LVENV_ASSET_URL"
            value = " "
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.wave_name_space,
    kubernetes_secret.wave-secrets,
    helm_release.wave-postgresql-ha,
    helm_release.wave-redis,
    helm_release.elastic,
  ]
}

resource "kubernetes_service" "wave-lv-example" {
  metadata {
    name = "wave-lv-example"
    namespace = local.wave_name_space
  }
  spec {
    selector = {
      app = "wave-lv-example"
    }
    port {
      port = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
  depends_on = [
    kubernetes_namespace.wave_name_space,
    kubernetes_secret.wave-secrets,
    helm_release.wave-postgresql-ha,
    helm_release.wave-redis,
    kubernetes_deployment.wave-lv-example,
  ]
}

resource "kubernetes_ingress" "wave-lv-example-ingres" {
  metadata {
    name = "wave-lv-example"
    namespace = local.wave_name_space
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls" = "true"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-traefik-compress@kubernetescrd"
      "cert-manager.io/cluster-issuer" = "letsencrypt-dns-production"
      "external-dns.alpha.kubernetes.io/hostname" = "${var.dns_domain},www.${var.dns_domain}"
      "traefik.ingress.kubernetes.io/redirect-regex" = "^https://www.${var.dns_domain}/(.*)"
      "traefik.ingress.kubernetes.io/redirect-replacement" = "https://${var.dns_domain}/$1"
    }
  }

  spec {
    rule {
//      host = "@.${var.dns_domain}"
      host = var.dns_domain
      http {
        path {
          path = "/"
          backend {
            service_name = "wave-lv-example"
            service_port = 80
          }
        }
      }
    }
    rule {
      host = "www.${var.dns_domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "wave-lv-example"
            service_port = 80
          }
        }
      }
    }
    tls {
      hosts = [
        var.dns_domain,
        "www.${var.dns_domain}"
      ]
      secret_name = "wave-cert-tls"
    }
  }
  depends_on = [
    kubernetes_namespace.wave_name_space,
    kubernetes_secret.wave-secrets,
    helm_release.wave-postgresql-ha,
    helm_release.wave-redis,
    kubernetes_deployment.wave-lv-example,
    kubernetes_service.wave-lv-example,
  ]
}
```

We follow a very similar setup and configuration compared to local.

Some of the differences is that we set up the PostgreSQL and Redis to be replicated.

We also move some of the more sensitive variables into Kubernetes secretes.

Then in the environmental configuration for the application we point to the secrets rather than
just specifying them directly.

We also don't make the DB externally accessable.

If you need to get access to the Database I would recommend using [Kube Forwarder](https://www.
electronjs.org/apps/kube-forwarder).

Kube Forwarder can map ports from an application in your cluster to your local pc.

#### Terraform applying

As everything is in terraform to spin the fully working cluster and application up.

You just specify the relevant variables and run ```terraform apply```.

To make your life simpler there is [./infra/terraform/apply.sh](./infra/terraform/apply.sh) to
do this.

So alter the file to your setting and then run.

```shell
./apply.sh
```

Then you just need to wait for everything to spin up.

The only steps left are to add the kubernetes cluster config and run the migrate and db seed.

First install [doctl](https://github.com/digitalocean/doctl).

Run the following to authenticate.

```shell
doctl auth init
```

As part of the output for the Terraform run it will print out the command similar to.

```shell
doctl kubernetes cluster kubeconfig save <id>
```

Run this to add the config for the cluster to your kubectl config.

Once you have done this you can just follow the same steps as for local.

First run

```shell
kubectl exec --tty --namespace wave -i $(kubectl get pods --namespace wave | grep wave-lv-example | awk '{print $1}') -- bash -c 'su - www-data'
```

This basically gets the pod for the Laravel application then execs into it.

Once we are in we just need run the following to update everything.

```shell
cd /var/www/site
yes | php artisan migrate
yes | php artisan db:seed
```

And you are done.

You should be able to access your application at https://example.com.
