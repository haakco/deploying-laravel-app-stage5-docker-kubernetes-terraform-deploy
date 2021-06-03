#!/usr/bin/env bash
kubectl delete --namespace kube-system -f ./keel/keel-ingres.tmpl.yaml
helm uninstall --namespace=kube-system keel

kubectl delete --namespace monitoring -f ./prometheus/prometheus-ingres.yaml

kubectl delete --namespace traefik -f ./traefik/traefik-monitoring.yml
kubectl delete --namespace traefik -f ./traefik/traefik-ingres.tmpl.yaml
helm uninstall --namespace traefik traefik
kubectl delete namespace traefik

kubectl delete --namespace cert-manager -f ./cert/acme-production.yaml
kubectl delete --namespace cert-manager -f ./cert/acme-staging.yaml
kubectl delete --namespace cert-manager -f ./cloudflare-apikey-secret.tmpl.yaml
helm uninstall --namespace cert-manager cert-manager
kubectl delete namespace cert-manager

helm uninstall --namespace monitoring prometheus-operator

kubectl delete crd alertmanagerconfigs.monitoring.coreos.com
kubectl delete crd alertmanagers.monitoring.coreos.com
kubectl delete crd podmonitors.monitoring.coreos.com
kubectl delete crd probes.monitoring.coreos.com
kubectl delete crd prometheuses.monitoring.coreos.com
kubectl delete crd prometheusrules.monitoring.coreos.com
kubectl delete crd servicemonitors.monitoring.coreos.com
kubectl delete crd thanosrulers.monitoring.coreos.com

kubectl delete namespace monitoring

helm uninstall --namespace kube-system kubernetes-dashboard

kubectl delete --namespace kube-system clusterrolebinding dashboard-admin-sa
kubectl delete --namespace kube-system serviceaccount dashboard-admin-sa
