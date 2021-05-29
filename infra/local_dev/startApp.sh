#!/usr/bin/env bash
setopt interactive_comments
export DOMAIN=dev.custd.com
export TRAEFIK_USERNAME='traefik'
export TRAEFIK_PASSWD='yairohchahKoo0haem0d'

kubectl create namespace wave

export DB_NAME=db_example
export DB_USER=user_example
export DB_PASS=password_example

cat ./wave/postgresql-values.tmpl.yaml | envsubst > ./wave/postgresql-values.env.yaml

kubectl apply --namespace wave -f ./wave/postgresql-pvc.yaml

helm install \
  wave-postgresql bitnami/postgresql \
  --namespace wave \
  -f ./wave/postgresql-values.env.yaml

export REDIS_PASS=password_example

cat ./wave/redis-values.tmpl.yaml | envsubst > ./wave/redis-values.env.yaml
helm install \
  wave-redis bitnami/redis \
  --namespace wave \
  -f ./wave/redis-values.env.yaml

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

cat ./wave/dev-wave-cert-prod.tmpl.yaml | envsubst > ./wave/dev-wave-cert-prod.env.yaml
kubectl apply --namespace wave  -f ./wave/dev-wave-cert-prod.env.yaml

cat ./wave/wave.deploy.tmpl.yaml | envsubst > ./wave/wave.deploy.env.yaml
kubectl apply --namespace wave -f ./wave/wave.deploy.env.yaml

#kubectl exec --tty --namespace wave -i $(kubectl get pods --namespace wave | grep wave-lv-example | awk '{print $1}') -- bash -c 'su - www-data'

#cd /var/www/site
#php artisan migrate
#php artisan db:seed
