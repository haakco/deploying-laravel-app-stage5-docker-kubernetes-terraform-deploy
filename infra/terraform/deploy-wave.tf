locals {
  name_space = "wave"
}

resource "kubernetes_namespace" "wave_name_space" {
  metadata {
    annotations = {
      name = local.name_space
    }

    name = local.name_space
  }
}

resource "kubernetes_secret" "wave-secrets" {
  metadata {
    name = "wave-secrets"
    namespace = local.name_space
  }

  data = {
    "postgresql-password" = var.wave_db_password
    "redis-password" = var.wave_redis_password
    "wave_app_mail_password" = var.wave_app_mail_password
    "wave_app_jwt_secret" = var.wave_app_jwt_secret
    "wave_app_key" = var.wave_app_key
  }

  type = "Opaque"
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
  namespace = local.name_space
  repository = "https://charts.bitnami.com/bitnami"
  chart = "postgresql-ha"
  version = "7.6.0"

  values = [
    data.template_file.wave_postgres.rendered
  ]

  depends_on = [
    kubernetes_namespace.wave_name_space,
    kubernetes_secret.wave-secrets,
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
  namespace = local.name_space
  repository = "https://charts.bitnami.com/bitnami"
  chart = "redis"
  version = "14.3.3"

  values = [
    data.template_file.wave_redis.rendered
  ]

  depends_on = [
    kubernetes_namespace.wave_name_space,
    kubernetes_secret.wave-secrets,
  ]
}

resource "kubernetes_deployment" "wave-lv-example" {
  metadata {
    name = "wave-lv-example"
    namespace = local.name_space
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
      }

      spec {
        container {
          image = "haakco/stage3-ubuntu-20.04-php7.4-lv-wave:latest"
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
            value = "TRUE"
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
    helm_release.wave-redis
  ]
}

resource "kubernetes_service" "wave-lv-example" {
  metadata {
    name = "wave-lv-example"
    namespace = local.name_space
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
    kubernetes_deployment.wave-lv-example
  ]
}

resource "kubernetes_ingress" "wave-lv-example-ingres" {
  metadata {
    name = "wave-lv-example"
    namespace = local.name_space
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls" = "true"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-traefik-compress@kubernetescrd"
      "cert-manager.io/cluster-issuer" = "letsencrypt-production"
      "external-dns.alpha.kubernetes.io/hostname" = "${var.dns_domain},www.${var.dns_domain}"
      "traefik.ingress.kubernetes.io/redirect-regex" = "^https://www.$DOMAIN/(.*)"
      "traefik.ingress.kubernetes.io/redirect-replacement" = "https://$DOMAIN/$1"
    }
  }

  spec {
    rule {
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
    kubernetes_service.wave-lv-example
  ]
}
