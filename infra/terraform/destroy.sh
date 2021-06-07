#!/usr/bin/env bash
if [[ -z ${CLOUDFLARE_API_TOKEN} ]] ; then
  echo "Please enter the CLOUDFLARE_API_TOKEN or set the env variable: "
  read -r CLOUDFLARE_API_TOKEN
else
  echo "Read CLOUDFLARE_API_TOKEN from env"
fi

export TF_VAR_traefik_username=""
export TF_VAR_traefik_password=""
export TF_VAR_traefik_auth=""
export TF_VAR_wave_registry_username=""
export TF_VAR_wave_registry_password=""

export TF_VAR_grafana_admin_password=""
terraform destroy -refresh=false -parallelism=1
