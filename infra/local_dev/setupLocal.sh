#!/usr/bin/env bash
setopt interactive_comments
. "$HOME"/.zshrc
export DOMAIN=dev.custd.com
export TRAEFIK_USERNAME='traefik'
export TRAEFIK_PASSWD='yairohchahKoo0haem0d'

kubectl create serviceaccount dashboard-admin-sa
kubectl create clusterrolebinding dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=default:dashboard-admin-sa

helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update
helm install \
  kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
  --namespace kube-system \
  --version 4.2.0

#kubectl describe secret $(kubectl get secrets | grep 'dashboard-admin' | awk '{print $1}')
#kubectl proxy &
#open "http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:https/proxy/#/login"

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install \
  metrics-server bitnami/metrics-server \
  --namespace kube-system \
  --version v5.8.9 \
  --set rbac.create=true \
  --set apiService.create=true \
  --set extraArgs.kubelet-insecure-tls=true

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

#https://www.digitalocean.com/community/tutorials/how-to-set-up-digitalocean-kubernetes-cluster-monitoring-with-helm-and-prometheus-operator
#http://www.dcasati.net/posts/installing-prometheus-on-kubernetes-v1.16.9/
#https://docs.syseleven.de/metakube/en/metakube-accelerator/building-blocks/observability-monitoring/kube-prometheus-stack
kubectl create namespace monitoring

helm install \
  prometheus-operator prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --version 16.1.0 \
  -f ./prometheus/prometheus-values.yaml

kubectl create namespace cert-manager
#kubectl delete namespace cert-manager

kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version 1.3.1 \
  --set installCRDs=true \
  --set prometheus.enabled=true \
  --set prometheus.servicemonitor.enabled=true

setLvDepProfile

cat ./cloudflare-apikey-secret.tmpl.yaml | envsubst > ./cloudflare-apikey-secret.env.yaml

kubectl --namespace cert-manager apply -f ./cloudflare-apikey-secret.env.yaml

# Remove key so we don't accidentally save it.
rm -rf ./cloudflare-apikey-secret.env.yaml

kubectl apply --namespace cert-manager -f ./cert/acme-production.yaml
kubectl apply --namespace cert-manager  -f ./cert/acme-staging.yaml

helm repo add traefik https://containous.github.io/traefik-helm-chart
helm repo update
kubectl create namespace traefik
helm install \
  traefik traefik/traefik \
  --namespace traefik \
  --version 9.1.1 \
  --values ./traefik/traefik-values.yaml

cat ./traefik/dev-traefik-cert.tmpl.yaml | envsubst > ./traefik/dev-traefik-cert.env.yaml
kubectl apply --namespace traefik -f ./traefik/dev-traefik-cert.env.yaml

TRAEFIK_AUTH=$(docker run --rm -ti xmartlabs/htpasswd "${TRAEFIK_USERNAME}" "${TRAEFIK_PASSWD}" | openssl base64 -A)
export TRAEFIK_AUTH

cat ./traefik/traefik-ingres.tmpl.yaml | envsubst > ./traefik/traefik-ingres.env.yaml
kubectl apply --namespace traefik -f ./traefik/traefik-ingres.env.yaml

kubectl apply --namespace traefik -f ./traefik/traefik-monitoring.yml

export PROMETHEUS_USERNAME="${TRAEFIK_USERNAME}"
export PROMETHEUS_PASSWD="${TRAEFIK_PASSWD}"

PROMETHEUS_AUTH=$(docker run --rm -ti xmartlabs/htpasswd "${PROMETHEUS_USERNAME}" "${PROMETHEUS_PASSWD}" | openssl base64 -A)
export PROMETHEUS_AUTH

export DOMAIN=$DOMAIN
cat ./prometheus/dev-prometheus-cert.tmpl.yaml | envsubst > ./prometheus/dev-prometheus-cert.env.yaml
kubectl apply --namespace monitoring -f ./prometheus/dev-prometheus-cert.env.yaml

cat ./prometheus/prometheus-ingres.tmpl.yaml | envsubst > ./prometheus/prometheus-ingres.env.yaml
kubectl apply --namespace monitoring -f ./prometheus/prometheus-ingres.env.yaml
