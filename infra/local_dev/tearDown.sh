#!/usr/bin/env bash
kubectl delete --namespace monitoring -f ./prometheus/prometheus-ingres.yaml
kubectl delete --namespace monitoring -f ./prometheus/dev-prometheus-cert.tmpl.yaml

kubectl delete --namespace traefik -f ./traefik/traefik-monitoring.yml
kubectl delete --namespace traefik -f ./traefik/traefik-ingres.tmpl.yaml
kubectl delete --namespace traefik -f ./traefik/dev-traefik-cert.tmpl.yaml
helm uninstall --namespace traefik traefik
kubectl delete namespace traefik

kubectl delete --namespace cert-manager -f ./cert/acme-production.yaml
kubectl delete --namespace cert-manager -f ./cert/acme-staging.yaml
kubectl delete --namespace cert-manager -f ./cloudflare-apikey-secret.tmp.yaml
helm uninstall --namespace cert-manager cert-manager
kubectl delete namespace cert-manager

helm uninstall --namespace monitoring prometheus-operator
kubectl delete namespace monitoring

helm uninstall --namespace kube-system metrics-server

helm uninstall --namespace kube-system kubernetes-dashboard

kubectl delete clusterrolebinding dashboard-admin-sa
kubectl delete serviceaccount dashboard-admin-sa
