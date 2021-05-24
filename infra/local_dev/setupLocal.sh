#!/usr/bin/env bash
export DOMAIN=dev.custd.com

kubectl create serviceaccount dashboard-admin-sa
kubectl create clusterrolebinding dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=default:dashboard-admin-sa

helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update
helm install \
  kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
  --namespace kube-system \
  --version 4.1.0

#kubectl describe secret $(kubectl get secrets | grep 'dashboard-admin' | awk '{print $1}')
#kubectl proxy &
#open "http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:https/proxy/#/login"

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install \
  metrics-server bitnami/metrics-server \
  --namespace kube-system \
  --version v5.8.7 \
  --set rbac.create=true \
  --set apiService.create=true \
  --set extraArgs.kubelet-insecure-tls=true

#helm uninstall \
#  --namespace kube-system \
#  metrics-server

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

#helm uninstall \
#  --namespace cert-manager \
#  cert-manager

kubectl --namespace cert-manager apply -f ./cloudflare-apikey-secret.yaml
kubectl --namespace cert-manager apply -f ./cert/acme-production.yaml
kubectl --namespace cert-manager apply -f ./cert/acme-staging.yaml

#kubectl --namespace cert-manager delete -f ./cloudflare-apikey-secret.yaml
#kubectl --namespace cert-manager delete -f ./cert/acme-production.yaml
#kubectl --namespace cert-manager delete -f ./cert/acme-staging.yaml

helm repo add traefik https://containous.github.io/traefik-helm-chart
helm repo update
kubectl create namespace traefik
helm install \
  traefik traefik/traefik \
  --namespace traefik \
  --version 9.1.1 \
  --values ./traefik/traefik-values.yaml

#helm uninstall helm install \
#  -n traefik traefik

cat ./traefik/dev-traefik-cert.tmpl.yaml | envsubst > ./traefik/dev-traefik-cert.yaml
kubectl apply -f ./traefik/dev-traefik-cert.yaml
#kubectl delete -f ./traefik/dev-traefik-cert.yaml

export TRAEFIK_USERNAME='traefik'
export TRAEFIK_PASSWD='yairohchahKoo0haem0d'

TRAEFIK_AUTH=$(docker run --rm -ti xmartlabs/htpasswd "${TRAEFIK_USERNAME}" "${TRAEFIK_PASSWD}" | openssl base64 -A)
export TRAEFIK_AUTH

cat ./traefik/traefik-ingres.tmpl.yaml | envsubst > ./traefik/traefik-ingres.yaml
kubectl apply -f ./traefik/traefik-ingres.yaml
#kubectl delete -f ./traefik/traefik-ingres.yaml

kubectl apply -f ./traefik/traefik-monitoring.yml

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

#https://www.digitalocean.com/community/tutorials/how-to-set-up-digitalocean-kubernetes-cluster-monitoring-with-helm-and-prometheus-operator
#http://www.dcasati.net/posts/installing-prometheus-on-kubernetes-v1.16.9/
#https://docs.syseleven.de/metakube/en/metakube-accelerator/building-blocks/observability-monitoring/kube-prometheus-stack
kubectl create namespace monitoring
#kubectl delete namespace monitoring

helm install \
  prometheus-operator prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --version 15.4.6 \
  -f ./prometheus/prometheus-values.yaml
#helm uninstall prometheus-operator --namespace monitoring

export PROMETHEUS_USERNAME="${TRAEFIK_USERNAME}"
export PROMETHEUS_PASSWD="${TRAEFIK_PASSWD}"

PROMETHEUS_AUTH=$(docker run --rm -ti xmartlabs/htpasswd "${PROMETHEUS_USERNAME}" "${PROMETHEUS_PASSWD}" | openssl base64 -A)
export PROMETHEUS_AUTH

export DOMAIN=$DOMAIN
cat ./prometheus/dev-prometheus-cert.tmpl.yaml | envsubst > ./prometheus/dev-prometheus-cert.yaml
kubectl apply -f ./prometheus/dev-prometheus-cert.yaml
#kubectl delete -f ./prometheus/dev-prometheus-cert.yaml
cat ./prometheus/prometheus-ingres.tmpl.yaml | envsubst > ./prometheus/prometheus-ingres.yaml
kubectl apply -f ./prometheus/prometheus-ingres.yaml
#kubectl delete -f ./prometheus/prometheus-ingres.yaml


kubectl create namespace wave

export DB_NAME=db_example
export DB_USER=user_example
export DB_PASS=password_example
cat ./wave/postgresql-values.tmpl.yaml | envsubst > ./wave/postgresql-values.yaml

helm install \
  wave-postgresql bitnami/postgresql \
  --namespace wave \
  -f ./wave/postgresql-values.yaml
#helm uninstall wave-postgresql --namespace wave

export REDIS_PASS=password_example

cat ./wave/redis-values.tmpl.yaml | envsubst > ./wave/redis-values.yaml
helm install \
  wave-redis bitnami/redis \
  --namespace wave \
  -f ./wave/redis-values.yaml
#helm uninstall wave-redis --namespace wave

export APP_KEY=base64:8dQ7xw/kM9EYMV4cUkzKgET8jF4P0M0TOmmqN05RN2w=
export APP_NAME=HaakCo Wave
export APP_ENV=local
export APP_DEBUG=true
export APP_LOG_LEVEL=debug
export DOMAIN_NAME=$DOMAIN
export DB_HOST=wave-postgresql
export DB_NAME=$DB_NAME
export DB_USER=$DB_USER
export DB_PASS=$DB_PASS
export REDIS_HOST=wave-redis-master
export REDIS_PASS=$REDIS_PASS
export MAIL_HOST=smtp.mailtrap.io
export MAIL_PORT=2525
export MAIL_USERNAME=
export MAIL_PASSWORD=
export MAIL_ENCRYPTION=null
export TRUSTED_PROXIES='10.0.0.0/8,172.16.0.0./12,192.168.0.0/16'
export JWT_SECRET=Jrsweag3Mf0srOqDizRkhjWm5CEFcrBy

WAVE_DIR=$(realpath "${PWD}/stage3-ubuntu-20.04-php7.4-lv-wave")
export WAVE_DIR

#export DOMAIN=$DOMAIN
#cat ./cert/dev-test-cert-staging.tmpl.yaml | envsubst > ./cert/dev-test-cert-staging.yaml
#kubectl --namespace wave apply -f ./cert/dev-test-cert-staging.yaml
#kubectl --namespace wave delete -f ./cert/dev-test-cert-staging.yaml

cat ./wave/dev-wave-cert-prod.tmpl.yaml | envsubst > ./wave/dev-wave-cert-prod.yaml
kubectl --namespace wave apply -f ./wave/dev-wave-cert-prod.yaml
#kubectl --namespace wave delete -f ./wave/dev-wave-cert-prod.yaml

cat ./wave/wave.deploy.tmpl.yaml | envsubst > ./wave/wave.deploy.yaml
kubectl apply \
  --namespace wave \
  -f ./wave/wave.deploy.yaml

#kubectl delete --namespace wave -f ./wave/wave.deploy.yaml

