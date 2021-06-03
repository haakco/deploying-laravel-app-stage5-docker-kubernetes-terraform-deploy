#!/usr/bin/env bash
if [[ -z ${CLOUDFLARE_API_TOKEN} ]] ; then
  echo "Please enter the CLOUDFLARE_API_TOKEN or set the env variable: "
  read -r CLOUDFLARE_API_TOKEN
else
  echo "Read CLOUDFLARE_API_TOKEN from env"
fi
terraform destroy -refresh=true -parallelism=10
