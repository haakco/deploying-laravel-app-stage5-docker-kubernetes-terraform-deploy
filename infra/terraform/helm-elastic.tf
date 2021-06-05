//resource "kubernetes_namespace" "elastic" {
//  metadata {
//    annotations = {
//      name = "elastic"
//    }
//    name = "elastic"
//  }
//}
//
//resource "helm_release" "elastic" {
//  name = "elastic-operator"
//  namespace = "elastic"
//  repository = "https://helm.elastic.co"
//  chart = "eck-operator"
//  version = "1.6.0"
//
//  set {
//    name  = "telemetry"
//    value = "true"
//  }
//  set {
//    name  = "config.metricsPort"
//    value = "9108"
//  }
//  set {
//    name  = "podMonitor.enabled"
//    value = "true"
//  }
//}
