#!/usr/bin/env bash

export DNS_DOMAIN='purplesocks.net'
export TRAEFIK_USERNAME='traefik'
export TRAEFIK_PASSWD='yairohchahKoo0haem0d'
export GRAFANA_ADMIN_PASSWORD='example_password'

if [[ -z ${CLOUDFLARE_API_TOKEN} ]]; then
  echo "Please enter the CLOUDFLARE_API_TOKEN or set the env variable: "
  read -r CLOUDFLARE_API_TOKEN
else
  echo "Read CLOUDFLARE_API_TOKEN from env"
fi
export CLOUDFLARE_API_TOKEN

export TF_VAR_cloudflare_api_token="${CLOUDFLARE_API_TOKEN}"

if [[ -z ${DIGITALOCEAN_TOKEN} ]]; then
  echo "Please enter the DIGITALOCEAN_TOKEN or set the env variable: "
  read -r DIGITALOCEAN_TOKEN
else
  echo "Read DIGITALOCEAN_TOKEN from env"
fi
export DIGITALOCEAN_TOKEN

export TF_VAR_do_token="${DIGITALOCEAN_TOKEN}"

export TF_VAR_dns_domain="${DNS_DOMAIN}"

export TF_VAR_traefik_username="${TRAEFIK_USERNAME}"
export TF_VAR_traefik_password="${TRAEFIK_PASSWD}"

TF_VAR_traefik_auth=$(docker run --rm -ti xmartlabs/htpasswd "${TRAEFIK_USERNAME}" "${TRAEFIK_PASSWD}")
export TF_VAR_traefik_auth

export TF_VAR_cloudflare_api_token=${CLOUDFLARE_API_TOKEN}
export TF_VAR_grafana_admin_password=${GRAFANA_ADMIN_PASSWORD}

export TF_VAR_wave_registry_username=${REGISTRY_USERNAME}
export TF_VAR_wave_registry_password=${REGISTRY_PASSWORD}

terraform apply -refresh=true -parallelism=10

#kubectl exec --tty --namespace wave -i $(kubectl get pods --namespace wave --field-selector status.phase=Running | grep wave-lv-example | head -n 1 | awk '{print $1}') -- bash -c 'su - www-data'

#cd /var/www/site
#yes | php artisan migrate
#yes | php artisan db:seed

echo 'kubectl exec --tty --namespace wave -i $(kubectl get pods --namespace wave --field-selector status.phase=Running | grep wave-lv-example | head -n 1 | awk '"'"'{print $1}'"'"') -- bash -c '"'"'su - www-data'"'"''
echo ""
echo "cd /var/www/site"
echo "yes | php artisan migrate"
echo "yes | php artisan db:seed"
