#!/usr/bin/env bash

setopt interactive_comments

if [[ -z ${CLOUDFLARE_API_TOKEN} ]] ; then
  echo "Please enter the CLOUDFLARE_API_TOKEN or set the env variable: "
  read -r CLOUDFLARE_API_TOKEN
else
  echo "Read CLOUDFLARE_API_TOKEN from env"
fi

export CLOUDFLARE_API_TOKEN

export DOMAIN=custd.com
export TRAEFIK_USERNAME='traefik'
export TRAEFIK_PASSWD='yairohchahKoo0haem0d'


kubectl create serviceaccount dashboard-admin-sa
kubectl create clusterrolebinding dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=default:dashboard-admin-sa

#kubectl create namespace external-dns
#kubectl delete namespace external-dns
#kubectl --namespace external-dns apply -f ./cloudflare-apikey-secret.yaml
#kubectl --namespace external-dns delete -f ./cloudflare-apikey-secret.yaml

#helm install \
#  external-dns bitnami/external-dns \
#  --namespace external-dns \
#  --version 5.0.0 \
#  --set provider=cloudflare \
#  --set domainFilters={$DOMAIN} \
#  --set cloudflare.proxied=true \
#  --set cloudflare.secretName=cloudflare-apikey \
#
#
#helm uninstall external-dns \
#  --namespace external-dns
