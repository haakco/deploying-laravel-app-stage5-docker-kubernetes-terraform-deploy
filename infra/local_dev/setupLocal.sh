#!/usr/bin/env bash
setopt interactive_comments

if [[ -z ${CLOUDFLARE_API_TOKEN} ]] ; then
  echo "Please enter the CLOUDFLARE_API_TOKEN or set the env variable: "
  read -r CLOUDFLARE_API_TOKEN
else
  echo "Read CLOUDFLARE_API_TOKEN from env"
fi

export CLOUDFLARE_API_TOKEN

export DOMAIN=dev.custd.com
export TRAEFIK_USERNAME='traefik'
export TRAEFIK_PASSWD='yairohchahKoo0haem0d'
export GRAFANA_ADMIN_PASSWORD=example_password

TRAEFIK_AUTH=$(docker run --rm -ti xmartlabs/htpasswd "${TRAEFIK_USERNAME}" "${TRAEFIK_PASSWD}" | openssl base64 -A)
export TRAEFIK_AUTH

kubectl create --namespace kube-system serviceaccount dashboard-admin-sa
kubectl create --namespace kube-system clusterrolebinding dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=default:dashboard-admin-sa

helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update
helm upgrade \
  --install \
  kubernetes-dashboard \
  --namespace kube-system \
  --version 4.2.0 \
  --set metricsScraper.enabled=true \
  --set metrics-server.enabled=true \
  --set metrics-server.args="{--kubelet-preferred-address-types=InternalIP,--kubelet-insecure-tls}" \
  kubernetes-dashboard/kubernetes-dashboard

#kubectl describe secret $(kubectl get secrets | grep 'dashboard-admin' | awk '{print $1}')
#kubectl proxy &
#open "http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:https/proxy/#/login"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

#https://www.digitalocean.com/community/tutorials/how-to-set-up-digitalocean-kubernetes-cluster-monitoring-with-helm-and-prometheus-operator
#http://www.dcasati.net/posts/installing-prometheus-on-kubernetes-v1.16.9/
#https://docs.syseleven.de/metakube/en/metakube-accelerator/building-blocks/observability-monitoring/kube-prometheus-stack
kubectl create namespace monitoring

cat ./prometheus/prometheus-values.tmpl.yaml | envsubst > ./prometheus/prometheus-values.env.yaml
kubectl apply --namespace monitoring -f ./prometheus/prometheus-values.env.yaml

helm upgrade \
  --install \
  prometheus-operator \
  --namespace monitoring \
  --version 16.1.2 \
  -f ./prometheus/prometheus-values.env.yaml \
  prometheus-community/kube-prometheus-stack

kubectl create namespace cert-manager
#kubectl delete namespace cert-manager

kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
helm install\
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version 1.3.1 \
  --set installCRDs=true \
  --set prometheus.servicemonitor.enabled=true

while [[ $(kubectl get pods --namespace cert-manager | grep 1/1 | wc -l | xargs) != "3" ]];
do
  echo "waiting for $(kubectl get pods --namespace cert-manager | grep 1/1 | wc -l | xargs)/3 cert-manager pods"
  sleep 1
done

cat ./cloudflare-apikey-secret.tmpl.yaml | envsubst > ./cloudflare-apikey-secret.env.yaml

kubectl --namespace cert-manager apply -f ./cloudflare-apikey-secret.env.yaml

# Remove key so we dont accidentally save it.
rm -rf ./cloudflare-apikey-secret.env.yaml

sleep 2

kubectl apply --namespace cert-manager -f ./cert/acme-production.yaml
kubectl apply --namespace cert-manager  -f ./cert/acme-staging.yaml

helm repo add traefik https://containous.github.io/traefik-helm-chart
helm repo update
kubectl create namespace traefik
helm upgrade \
  --install \
  traefik \
  --namespace traefik \
  --version 9.1.1 \
  --values ./traefik/traefik-values.yaml \
  traefik/traefik

cat ./traefik/traefik-ingres.tmpl.yaml | envsubst > ./traefik/traefik-ingres.env.yaml
kubectl apply --namespace traefik -f ./traefik/traefik-ingres.env.yaml

kubectl apply --namespace traefik -f ./traefik/traefik-monitoring.yml

cat ./prometheus/prometheus-ingres.tmpl.yaml | envsubst > ./prometheus/prometheus-ingres.env.yaml
kubectl apply --namespace monitoring -f ./prometheus/prometheus-ingres.env.yaml

cat ./keel/keel-values.tmpl.yml | envsubst > ./keel/keel-values.env.yaml
helm repo add keel https://charts.keel.sh
helm repo update
helm upgrade \
  --install keel \
  --namespace=kube-system \
  --version 0.9.8 \
  --values ./keel/keel-values.env.yaml \
  keel/keel

cat ./keel/keel-ingres.tmpl.yaml | envsubst > ./keel/keel-ingres.env.yaml
kubectl apply --namespace kube-system -f ./keel/keel-ingres.env.yaml


