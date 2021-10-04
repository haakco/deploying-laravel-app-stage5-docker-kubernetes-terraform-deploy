#!/usr/bin/env zsh
autoload colors; colors

#purplesocks.net
export DNS_DOMAIN='example.com'
export TRAEFIK_USERNAME='traefik'
export TRAEFIK_PASSWD='yairohchahKoo0haem0d'
export GRAFANA_ADMIN_PASSWORD='example_password'

if [[ -z ${CLOUDFLARE_API_TOKEN} ]]; then
  echo "$fg[green]Please enter the CLOUDFLARE_API_TOKEN or set the env variable$reset_color: "
  read -r CLOUDFLARE_API_TOKEN
else
  echo "Read CLOUDFLARE_API_TOKEN from env"
fi
export CLOUDFLARE_API_TOKEN

export TF_VAR_cloudflare_api_token="${CLOUDFLARE_API_TOKEN}"

if [[ -z ${DIGITALOCEAN_TOKEN} ]]; then
  echo "$fg[green]Please enter the DIGITALOCEAN_TOKEN or set the env variable$reset_color: "
  read -r DIGITALOCEAN_TOKEN
else
  echo "Read DIGITALOCEAN_TOKEN from env"
fi
export DIGITALOCEAN_TOKEN



#if [[ -z ${KUBERNETES_VERSION} ]]; then
#  echo "$fg[green]Please run the following in a $fg[white]separate$fg[green] window and paste the slug for the K8 version you would like to use$reset_color"
#  echo ""
#  echo "doctl kubernetes options versions"
#  echo ""
#  echo "$fg[green]Then press enter$reset_color"
#  read -r KUBERNETES_VERSION
#else
#  echo "Grabbed kubernetes version from env"
#  echo "K8 Ver set to: ${KUBERNETES_VERSION}"
#fi
#export KUBERNETES_VERSION
#export TF_VAR_kubernetes_version="${KUBERNETES_VERSION}"

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

echo "About to run terraform apply"
terraform apply -refresh=true -parallelism=10

#kubectl exec --tty --namespace wave -i $(kubectl get pods --namespace wave --field-selector status.phase=Running | grep wave-lv-example | head -n 1 | awk '{print $1}') -- bash -c 'su - www-data'

#cd /var/www/site
#yes | php artisan migrate
#yes | php artisan db:seed

echo 'kubectl exec --tty --namespace wave -i $(kubectl get pods --namespace wave --field-selector status.phase=Running | grep wave-lv-example | head -n 1 | awk '"'"'{print $1}'"'"') -- bash -c '"'"'su - www-data'"'"''
echo ""
echo ""
echo "cd /var/www/site/; yes | php artisan migrate"
echo "cd /var/www/site/;yes | php artisan db:seed"
