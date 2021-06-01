#!/usr/bin/env bash
terraform init
terraform providers lock \
  -platform=linux_arm64 \
  -platform=linux_amd64 \
  -platform=darwin_amd64 \
  -platform=windows_amd64

export TRAEFIK_USERNAME='traefik'
export TRAEFIK_PASSWD='yairohchahKoo0haem0d'

TF_VAR_traefik_auth=$(docker run --rm -ti xmartlabs/htpasswd "${TRAEFIK_USERNAME}" "${TRAEFIK_PASSWD}" | openssl base64 -A)
export TF_VAR_traefik_auth

terraform apply -refresh=true -parallelism=10
