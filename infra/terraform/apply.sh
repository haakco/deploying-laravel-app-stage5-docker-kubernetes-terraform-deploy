#!/usr/bin/env bash
export TRAEFIK_USERNAME='traefik'
export TRAEFIK_PASSWD='yairohchahKoo0haem0d'
export GRAFANA_ADMIN_PASSWORD='example_password'

if [[ -z ${CLOUDFLARE_API_TOKEN} ]]; then
  echo "Please enter the CLOUDFLARE_API_TOKEN or set the env variable: "
  read -r CLOUDFLARE_API_TOKEN
else
  echo "Read CLOUDFLARE_API_TOKEN from env"
fi

export TF_VAR_traefik_username="${TRAEFIK_USERNAME}"
export TF_VAR_traefik_password="${TRAEFIK_PASSWD}"

TF_VAR_traefik_auth=$(docker run --rm -ti xmartlabs/htpasswd "${TRAEFIK_USERNAME}" "${TRAEFIK_PASSWD}")
export TF_VAR_traefik_auth

export TF_VAR_cloudflare_api_token=${CLOUDFLARE_API_TOKEN}
export TF_VAR_grafana_admin_password=${GRAFANA_ADMIN_PASSWORD}

terraform apply -refresh=true -parallelism=10

#kubectl exec --tty --namespace wave -i $(kubectl get pods --namespace wave --field-selector status.phase=Running | grep wave-lv-example | head -n 1 | awk '{print $1}') -- bash -c 'su - www-data'

#cd /var/www/site
#php artisan migrate
#php artisan db:seed

echo 'kubectl exec --tty --namespace wave -i $(kubectl get pods --namespace wave --field-selector status.phase=Running | grep wave-lv-example | head -n 1 | awk '"'"'{print $1}'"'"') -- bash -c '"'"'su - www-data'"'"''
echo ""
echo "cd /var/www/site"
echo "php artisan migrate"
echo "php artisan db:seed"
