# Stage 5: Kubernetes and Terraform deploy

## Intro

This stage covers how to deploy to kubernetes and set up a local kubernetes development enviroment.

### Pros

* Very repeatable
* Faster from nothing to fully setup
* Can replicate the entire infrastructure for dev or staging.
* Everything documented.
* Simple high availability
* Quick to set up entire enviroment once setup.

### Cons

* Very complicated.
* Takes longer to set up initial scripts.
* Require knowledge for far more application and moving pieces.
* As everything is automated you have to be far more careful not so break something.

## Assumptions

1. Php code is in git.
1. You are using PostgreSQL.
1. If not, replace the PostgreSQL step with your DB of choice.
1. You have a server.
1. In this example and future ones, we'll be deploying
   to [DigitalOcean](https://m.do.co/c/179a47e69ec8)
   but the steps should mostly work with any servers.
1. The server is running Ubuntu 20.04 or Kubernetes cluster.
1. You have SSH key pair.
1. Needed to log into your server securely.
1. You have a Domain Name, and you can add entries to point to the server.
1. We'll be using example.com here. Just replace that with your domain of choice.
1. For DNS, I'll be using [Cloudflare](https://www.cloudflare.com/) in these examples.
1. I would recommend using a DNS provider that supports [Terraform](https://www.terraform.io/) and
   [LetsEncrypt](https://community.letsencrypt.org/t/dns-providers-who-easily-integrate-with-lets-encrypt-dns-validation/86438)

## Docker Images

Once again for dev we'll be using the following docker image:

* https://github.com/haakco/deploying-laravel-app-docker-ubuntu-php-lv

For production, we'll be using the same one previously as well:

* https://github.com/haakco/deploying-laravel-app-ubuntu-20.04-php7.4-lv-wave

## Development Setup

### Script

I've provided a script that should fully set up your local enviroment.

[./infra/local_dev/setupLocal.sh](./infra/local_dev/setupLocal.sh)

All the steps bellow are also in the script.

Just remember to change the variables to your local enviroment.

### Environmental variables

Kubectl doesn't pay attention to environmental variables we'll be
using [envsubst](https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html)

This basically takes a file and replaces the variables with your environmental variables.

We'll then run the resulting file.

This is mainly to just allow us to easily change setting, it also means we don't have to store
secrets in our files.

Generally you would just pipe the result from envsubst to kubectl. In the scripts I'm rather
creating a file and then running that.

This is done so that you can see and check what the created file actually looks like.

Long term you should possible look at something like [Vault](https://www.vaultproject.io/) or
[1Password Secrets](https://support.1password.com/connect-deploy-kubernetes/).

### Settings

We'll be configuring most of the simple setting via environmental variables.

All the scripts are un assuming the following are set.

```shell
if [[ -z ${CLOUDFLARE_API_TOKEN} ]] ; then
  echo "Please enter the CLOUDFLARE_API_TOKEN or set the env variable: "
  read -r CLOUDFLARE_API_TOKEN
else
  echo "Read CLOUDFLARE_API_TOKEN from env"
fi

export CLOUDFLARE_API_TOKEN

export DOMAIN=dev.custd.com
export CERT_EMAIL="cert@${DOMAIN}"
export TRAEFIK_USERNAME='traefik'
export TRAEFIK_PASSWD='yairohchahKoo0haem0d'
export GRAFANA_ADMIN_PASSWORD=example_password

TRAEFIK_AUTH=$(docker run --rm -ti xmartlabs/htpasswd "${TRAEFIK_USERNAME}" "${TRAEFIK_PASSWD}" | openssl base64 -A)
export TRAEFIK_AUTH
```

### Helm

I'll be mainly using [Helm](https://Helm.sh/) to deploy services like the DB.

This is done to just decrease the amount of things that you have to manage.

The actual application I'm doing via Yaml files, so we have complete controll over how its deployed
and configured.

I'll be locking all the Helm installs to a specific version.

I've had random things break with different chart versions, so it's safer to lock the installation
down to a version.

### Setting up local enviroment.

For the local enviroment I'm using [Docker Desktop](https://www.docker.com/products/docker-desktop)
with kubernetes enabled.

There are several alternatives.

We are then going to enable our Kubernetes enviroment first, by adding tools to make our lives
simpler and provide reporting.

### Namespaces

We'll be splitting applications into separate namespaces.

This is to make it easier manage things and simpler cleanup.

#### Kubernetes Dashboard

We'll start with adding [Kubernetes Dashboard](https://kubernetes.
io/docs/tasks/access-application-cluster/web-ui-dashboard/).

This make it easier to see what's going on quickly and get access to log and terminal access.

```shell
kubectl create --namespace kube-system serviceaccount dashboard-admin-sa
kubectl create clusterrolebinding dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=kube-system:dashboard-admin-sa

Helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
Helm repo update
Helm upgrade \
  --install \
  kubernetes-dashboard \
  --namespace kube-system \
  --version 4.2.0 \
  --set metricsScraper.enabled=true \
  --set metrics-server.enabled=true \
  --set metrics-server.args="{--kubelet-preferred-address-types=InternalIP,--kubelet-insecure-tls}" \
  kubernetes-dashboard/kubernetes-dashboard
```

For security, we are going to first create a service account and grant it rights to access the
allowed Dashboard to access all the sections once you are logged in.

We then add the Helm repository and then install vial Helm.

We also change the Helm setting to install metrics server and the metrics scraper.

As we are installing on [Docker Desktop](https://www.docker.com/products/docker-desktop) we need to
disable tls security.

Once the kubernetes dashboard is finished deploying you can access by starting the kubernetes proxy.

```shell
kubectl proxy
```

Then opening the dashboard url in your browser
http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:https/proxy/#/login
.

```shell
open "http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:https/proxy/#/login"
```

This will prompt your for a token. We'll get this for the serviceaccount we created previously.

I find it simpler to create an alias to get the token.

Add the following to your ```.bashrc``` or your ```.zshrc```.

```shell
alias getKubeTokenKS='kubectl describe secret --namespace kube-system $(kubectl get secrets --namespace kube-system | grep "dashboard-admin-sa-token" | awk '"'"'{print $1}'"'"')'
```

Just type getKubeTokenKS to get the token.

Alternatively you can also look at [Lens](https://k8slens.dev/). This may be helpful if dashboard is
broken or not installed.

#### Monitoring and Alerting

We'll be using the [prometheus-operator](https://github.
com/prometheus-operator/prometheus-operator) for monitoring and alerting.

This will install [Prometheus](https://prometheus.io/), [AlertManager](https://github.
com/prometheus/alertmanager) and [Grafana](https://grafana.com/).

I'll be mainly covering how to install this.

Once again we'll be using the Helm chart to install this.

We also need to do a bit more configuration that the previous chart.

Bellow is the configuration.

We'll be using envsubst to replace the variables.

[./infra/local_dev/monitoring/prometheus-values.tmpl.yaml](./infra/local_dev/monitoring/prometheus-values.tmpl.yaml)

```yaml
---
grafana:
  adminPassword: $GRAFANA_ADMIN_PASSWORD
  grafana.ini:
    server:
      root_url: https://grafana.$DOMAIN
prometheus-node-exporter:
  hostRootFsMount: false
alertmanager:
  alertmanagerSpec:
    externalUrl: https://alertmanager.$DOMAIN
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false
    externalUrl: https://prometheus.$DOMAIN

# Disable Etcd metrics
kubeEtcd:
  enabled: false

# Disable Controller metrics
kubeControllerManager:
  enabled: false

# Disable Scheduler metrics
kubeScheduler:
  enabled: false
```

We'll also create a new namespace for monitoring.

```shell
Helm repo add prometheus-community https://prometheus-community.github.io/Helm-charts
Helm repo update

kubectl create namespace monitoring
cat ./monitoring/prometheus-values.tmpl.yaml | envsubst > ./monitoring/prometheus-values.env.yaml
kubectl apply --namespace monitoring -f ./monitoring/prometheus-values.env.yaml

Helm upgrade \
  --install \
  prometheus-operator \
  --namespace monitoring \
  --version 16.1.2 \
  -f ./monitoring/prometheus-values.env.yaml \
  prometheus-community/kube-prometheus-stack
```

We'll be adding the ingress routes (Making the systems externally visible) later once we've added
Traefik.

#### Cert Manager

To generate certificates for our end points we'll be using [CertManager](https://cert-manager.io/).

We could do this with Traefik it unfortunately doesn't do it in a high availability way.

If you wish to replace Traefik with something
like [Ingress Nginx](https://kubernetes.github.io/ingress-nginx/)
it should be quiet simple.

```shell
kubectl create namespace cert-manager
#kubectl delete namespace cert-manager

kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
Helm install\
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version 1.3.1 \
  --set installCRDs=true \
  --set prometheus.servicemonitor.enabled=true
```

*The following is the configuration for CloudFlare. Please change to your preferred provider.*

Next we need to add the CloudFlare api token as a secret.

[./infra/local_dev/cloudflare-apikey-secret.tmpl.yaml](./infra/local_dev/cloudflare-apikey-secret.tmpl.yaml)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-apikey
type: Opaque
stringData:
  cloudflare_api_token: $CLOUDFLARE_API_TOKEN
```

```shell
cat ./cloudflare-apikey-secret.tmpl.yaml | envsubst | \
  kubectl --namespace cert-manager apply -f -
```

We now need to add the configuration for the certificate cluster issuer.

In the script we add one for staging and one for production.

I'm just going to show the production one here.

```yaml
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
  namespace: cert-manager
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: $CERT_EMAIL
    privateKeySecretRef:
      name: letsencrypt-staging-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-apikey
              key: cloudflare_api_token
```

```shell
cat ./cert/acme-dns-production.tmpl.yaml | envsubst > ./cert/acme-dns-production.env.yaml
kubectl apply --namespace cert-manager -f ./cert/acme-dns-production.env.yaml
```

This certificate cluster issuer can now be used in our traefik ingress.

#### Traefik

Now that we have all the supporting services added we can add Traefik.

First we have the Helm configuration file.

[./infra/local_dev/traefik/traefik-values.tmpl.yaml](./infra/local_dev/traefik/traefik-values.tmpl.yaml)
```yaml
---
ports:
  traefik:
    expose: false
additionalArguments:
  - "--api"
  - "--api.insecure=true"
  - "--api.dashboard=true"
  - "--log.level=INFO"
  - "--entrypoints.websecure.http.tls"
  - "--providers.kubernetesingress=true"
  - "--ping"
  - "--metrics.prometheus=true"
  - "--metrics.prometheus.addEntryPointsLabels=true"
  - "--metrics.prometheus.addServicesLabels=true"
  - "--entryPoints.websecure.proxyProtocol.insecure=true"
  - "--entrypoints.web.http.redirections.entrypoint.to=:443"
  - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
  - >-
    --entryPoints.websecure.proxyProtocol.trustedIPs=127.0.0.1,10.10.0.0/16,172.17.0.0/12,173.245.48.0/20,103.21.244.0/22,
    103.22.200.0/22,103.31.4.0/22,141.101.64.0/18,108.162.192.0/18,190.93.240.0/20,188.114.96.0/20,197.234.240.0/22,
    198.41.128.0/17,162.158.0.0/15,104.16.0.0/13,104.24.0.0,172.64.0.0/13,131.0.72.0/22,2400:cb00::/32,2606:4700::/32,
    2803:f800::/32,2405:b500::/32,2405:8100::/32,2a06:98c0::/29,2c0f:f248::/32
  - "--entryPoints.websecure.forwardedHeaders.insecure=true"
  - >-
    --entryPoints.websecure.forwardedHeaders.trustedIPs=127.0.0.1,10.10.0.0/16,172.17.0.0/12,173.245.48.0/20,103.21.244.0/22,
    103.22.200.0/22,103.31.4.0/22,141.101.64.0/18,108.162.192.0/18,190.93.240.0/20,188.114.96.0/20,197.234.240.0/22,
    198.41.128.0/17,162.158.0.0/15,104.16.0.0/13,104.24.0.0,172.64.0.0/13,131.0.72.0/22,2400:cb00::/32,2606:4700::/32,
    2803:f800::/32,2405:b500::/32,2405:8100::/32,2a06:98c0::/29,2c0f:f248::/32
  - "--accesslog=true"
  - "--accesslog.format=json"
  - "--accesslog.bufferingSize=128"
  - "--accessLog.fields.defaultmode=keep"
  - "--accessLog.fields.names.ClientUsername=keep"
  - "--accessLog.fields.headers.defaultmode=keep"
  - "--accessLog.fields.headers.names.User-Agent=keep"
  - "--accessLog.fields.headers.names.Authorization=keep"
  - "--accessLog.fields.headers.names.Content-Type=keep"
  - "--accessLog.fields.headers.names.CF-Connecting-IP=keep"
  - "--accessLog.fields.headers.names.Cf-Ipcountry=keep"
  - "--accessLog.fields.headers.names.X-Forwarded-For=keep"
  - "--accessLog.fields.headers.names.X-Forwarded-Proto=keep"
  - "--accessLog.fields.headers.names.Cf-Ray=keep"
  - "--accessLog.fields.headers.names.Cf-Visitor=keep"
  - "--accessLog.fields.headers.names.True-Client-IP=keep"

deployment:
  replicas: 1
```

This basically enables the traefik to enable its dashboard, to accept proxy headers from CloudFlare
IPs and to automatically redirect http to https.

Once we have that we can then install traefik via Helm.

```shell
kubectl create namespace traefik

Helm repo add traefik https://containous.github.io/traefik-Helm-chart
Helm repo update

cat ./traefik/traefik-values.tmpl.yaml | envsubst > ./traefik/traefik-values.env.yaml

Helm upgrade \
  --install \
  traefik \
  --namespace traefik \
  --version 9.1.1 \
  --values ./traefik/traefik-values.env.yaml \
  traefik/traefik
```

Once this is installed we can now add ingress routes for the traefik dashboard and the prometheus
endpoints.

We also add [Traefik middleware](https://doc.traefik.io/traefik/middlewares/overview/) for basic
authentication and for compression.

This middleware is re-used for any other ingress routes we need to add.

[./infra/local_dev/traefik/traefik-ingres.tmpl.yaml](./infra/local_dev/traefik/traefik-ingres.tmpl.yaml)
```yaml
---
kind: Service
apiVersion: v1
metadata:
  name: traefik-web-ui
  namespace: traefik
spec:
  selector:
    app.kubernetes.io/instance: traefik
    app.kubernetes.io/name: traefik
  ports:
    - name: web
      port: 9000
      targetPort: 9000
---
# Declaring the user list
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: traefik-auth
  namespace: traefik
spec:
  basicAuth:
    secret: traefik-authsecret
---
apiVersion: v1
kind: Secret
metadata:
  name: traefik-authsecret
  namespace: traefik
data:
  users: $TRAEFIK_AUTH
type: Opaque
---
# Enable gzip compression
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: traefik-compress
  namespace: traefik
spec:
  compress: { }
---
kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  name: traefik
  namespace: traefik
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.middlewares: traefik-traefik-compress@kubernetescrd,traefik-traefik-auth@kubernetescrd
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  tls:
    - hosts:
        - traefik.$DOMAIN
      secretName: traefik-cert-tls
  rules:
    - host: traefik.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: traefik-web-ui
                port:
                  number: 9000
```

```shell
cat ./traefik/traefik-ingres.tmpl.yaml | envsubst > ./traefik/traefik-ingres.env.yaml
kubectl apply --namespace traefik -f ./traefik/traefik-ingres.env.yaml
```

You can look at the annotations to see how cert manager and traefik are configured.

```yaml
annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.middlewares: traefik-traefik-compress@kubernetescrd,traefik-traefik-auth@kubernetescrd
    cert-manager.io/cluster-issuer: letsencrypt-production
```

[./infra/local_dev/monitoring/prometheus-ingres.tmpl.yaml](./infra/local_dev/monitoring/prometheus-ingres.tmpl.yaml)
```yaml
---
kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  name: prometheus
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.middlewares: traefik-traefik-compress@kubernetescrd,traefik-traefik-auth@kubernetescrd
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  tls:
    - hosts:
        - prometheus.$DOMAIN
        - alertmanager.$DOMAIN
      secretName: prometheus-cert-tls
  rules:
    - host: prometheus.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: prometheus-operated
                port:
                  number: 9090
    - host: alertmanager.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: alertmanager-operated
                port:
                  number: 9093
---
kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.middlewares: traefik-traefik-compress@kubernetescrd
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  tls:
    - hosts:
        - grafana.$DOMAIN
      secretName: grafana-cert-tls
  rules:
    - host: grafana.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: prometheus-operator-grafana
                port:
                  number: 80
```

```shell
cat ./monitoring/prometheus-ingres.tmpl.yaml | envsubst > ./monitoring/prometheus-ingres.env.yaml
kubectl apply --namespace monitoring -f ./monitoring/prometheus-ingres.env.yaml
```

#### Image updating / Keel

The final bit for our setup of the kubernetes system is to add [Keel](https://keel.sh/).

We use this to allow for automatic updating of our application images.

Rather than adding a global config we'll be adding annotations to the relevant deployments on 
how we want the images to be updated.

This installation follows the same patter as the previous ones.

Set up the config file, install via Helm using the config and add a ingres route.

[./infra/local_dev/keel/keel-values.tmpl.yml](./infra/local_dev/keel/keel-values.tmpl.yml)
```yaml
---
basicauth:
  enabled: true
  user: $TRAEFIK_USERNAME
  password: $TRAEFIK_PASSWD
ingress:
  enabled: false
HelmProvider:
  version: "v3"
```

[./infra/local_dev/keel/keel-ingres.tmpl.yaml](./infra/local_dev/keel/keel-ingres.tmpl.yaml)
```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: keel
spec:
  type: ClusterIP
  ports:
    - port: 9300
      targetPort: 9300
  selector:
    app: keel
---
kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  name: keel
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.middlewares: traefik-traefik-compress@kubernetescrd
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  tls:
    - hosts:
        - keel.$DOMAIN
      secretName: keel-cert-tls
  rules:
    - host: keel.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: keel
                port:
                  number: 9300

```

```shell

cat ./keel/keel-values.tmpl.yml | envsubst > ./keel/keel-values.env.yaml
Helm repo add keel https://charts.keel.sh
Helm repo update
Helm upgrade \
  --install keel \
  --namespace=kube-system \
  --version 0.9.8 \
  --values ./keel/keel-values.env.yaml \
  keel/keel

cat ./keel/keel-ingres.tmpl.yaml | envsubst > ./keel/keel-ingres.env.yaml
kubectl apply --namespace kube-system -f ./keel/keel-ingres.env.yaml
```

#### Deploying Laravel

I've split the deployment of the laravel application off to simplify things.

It also means if you want you can run multiple applications on the same kubernetes environment.

You can see the full script at

[./infra/local_dev/startApp.sh](./infra/local_dev/startApp.sh)

##### Environmental Variables

There are a couple environmental variables in the run script. Please alter then to suit your 
enviroment.

Please note the WAVE_DIR which should point to the location of your Laravel code.

```shell
export DOMAIN=dev.custd.com
export TRAEFIK_USERNAME='traefik'
export TRAEFIK_PASSWD='yairohchahKoo0haem0d'

export DB_NAME=db_example
export DB_USER=user_example
export DB_PASS=password_example
export DB_EXTERNAL_PORT=30432

export REDIS_PASS=password_example

if [[ -z ${REGISTRY_USERNAME} ]] ; then
  echo "Please enter the REGISTRY_USERNAME or set the env variable: "
  read -r REGISTRY_USERNAME
else
  echo "Read REGISTRY_USERNAME from env"
fi

if [[ -z ${REGISTRY_PASSWORD} ]] ; then
  echo "Please enter the REGISTRY_PASSWORD or set the env variable: "
  read -r REGISTRY_PASSWORD
else
  echo "Read REGISTRY_PASSWORD from env"
fi

export REGISTRY_URL='https://index.docker.io/v2/'
export REGISTRY_NAME='docker-hub'

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

WAVE_DIR=$(realpath "${PWD}/../../../deploying-laravel-app-ubuntu-20.04-php7.4-lv-wave")
export WAVE_DIR
```

##### Namespace

Next we create a specific names space for the application.

```shell
kubectl create namespace wave
```

##### Registry Auth

In this example the docker image is public , though for most real life your 
images will most likely be private.

To access these you'll need registry auth.

So we first add the secret for registry auth.

```shell
kubectl \
  --namespace wave \
  create secret \
  docker-registry "${REGISTRY_NAME}" \
  --docker-server="${REGISTRY_URL}" \
  --docker-username="${REGISTRY_USERNAME}" \
  --docker-password="${REGISTRY_PASSWORD}" \
  --docker-email=""
```

##### Database

Ok now we need to setup our database.

We first want to create volume claim to make sure our database is persisted.

[./infra/local_dev/wave/postgresql-pvc.yaml](./infra/local_dev/wave/postgresql-pvc.yaml)
```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: postgres-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

Next we install postgres via a Helm chart.

First we set the config values.

[./infra/local_dev/wave/postgresql-values.tmpl.yaml](./infra/local_dev/wave/postgresql-values.tmpl.yaml)
```yaml
---
image:
  tag: 13
  pullPolicy: Always
postgresqlDatabase: $DB_NAME
postgresqlUsername: $DB_USER
postgresqlPassword: $DB_PASS
#existingSecret:
metrics:
  enabled: true
persistence:
  enabled: true
  existingClaim: postgres-pvc
service:
  type: NodePort
  nodePort: $DB_EXTERNAL_PORT
```

You'll see we lock the version down to 13 just as we did the in previous stage.

We also set it to create a service for postgres, so we can make it externally accessible.

Next we replace the variables and then install the Helm chart.

```shell
kubectl apply --namespace wave -f ./wave/postgresql-pvc.yaml

cat ./wave/postgresql-values.tmpl.yaml | envsubst > ./wave/postgresql-values.env.yaml
helm upgrade \
  --install \
  wave-postgresql \
  --namespace wave \
  --version 10.4.8 \
  -f ./wave/postgresql-values.env.yaml \
  bitnami/postgresql
```

##### Redis

We follow almost exactly the same process for redis as we did for postgres.

Create the persistent volume. 

[./infra/local_dev/wave/redis-pvc.yaml](./infra/local_dev/wave/redis-pvc.yaml)
```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: redis-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

Then set the Helm values.

[./infra/local_dev/wave/redis-values.tmpl.yaml](./infra/local_dev/wave/redis-values.tmpl.yaml)
```yaml
---
architecture: standalone
image:
  pullPolicy: Always
auth:
  password: $REDIS_PASS
master:
  persistence:
    existingClaim:
      redis-pvc
```

Finally, we install everything.

```shell
kubectl apply --namespace wave -f ./wave/redis-pvc.yaml

cat ./wave/redis-values.tmpl.yaml | envsubst > ./wave/redis-values.env.yaml
helm upgrade \
  --install \
  wave-redis \
  --namespace wave \
  --version 14.3.3 \
  -f ./wave/redis-values.env.yaml \
  bitnami/redis
```

##### Deploy Laravel Application

To deploy the Laravel application we'll first create a deployment, we'll then make it visible to 
the cluster and finally we'll make it accessible via an ingress route and Traefik.

You could split these into seperate files.

I've put them all in the same file to show they should all be run together.

So first lets deploy the application.

###### Deploy
[./infra/local_dev/wave/wave.deploy.tmpl.yaml](./infra/local_dev/wave/wave.deploy.tmpl.yaml)
```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wave-lv-example
  annotations:
    keel.sh/policy: force
    keel.sh/trigger: poll
    keel.sh/pollSchedule: "@every 5m"
spec:
  revisionHistoryLimit: 1
  selector:
    matchLabels:
      app: wave-lv-example
  replicas: 1
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 25%
  template:
    metadata:
      labels:
        app: wave-lv-example
    spec:
      imagePullSecrets:
        - name: docker-hub
      containers:
        - name: wave-lv-example
          image: haakco/deploying-laravel-app-ubuntu-20.04-php7.4-lv
          ports:
            - containerPort: 80
          env:
            - name: ENABLE_HORIZON
              value: "FALSE"
            - name: CRONTAB_ACTIVE
              value: "TRUE"
            - name: GEN_LV_ENV
              value: "TRUE"
            - name: LVENV_APP_NAME
              value: "$APP_NAME"
            - name: LVENV_APP_ENV
              value: "$APP_ENV"
            - name: LVENV_APP_KEY
              value: "$APP_KEY"
            - name: LVENV_APP_DEBUG
              value: "$APP_DEBUG"
            - name: LVENV_APP_LOG_LEVEL
              value: "$APP_LOG_LEVEL"
            - name: LVENV_APP_URL
              value: "https://$DOMAIN_NAME"
            - name: LVENV_DB_CONNECTION
              value: "pgsql"
            - name: LVENV_DB_HOST
              value: "$DB_HOST"
            - name: LVENV_DB_PORT
              value: "5432"
            - name: LVENV_DB_DATABASE
              value: "$DB_NAME"
            - name: LVENV_DB_USERNAME
              value: "$DB_USER"
            - name: LVENV_DB_PASSWORD
              value: "$DB_PASS"
            - name: LVENV_BROADCAST_DRIVER
              value: "log"
            - name: LVENV_CACHE_DRIVER
              value: "redis"
            - name: LVENV_SESSION_DRIVER
              value: "redis"
            - name: LVENV_SESSION_LIFETIME
              value: "9999"
            - name: LVENV_QUEUE_DRIVER
              value: "redis"
            - name: LVENV_REDIS_HOST
              value: "$REDIS_HOST"
            - name: LVENV_REDIS_PASSWORD
              value: "$REDIS_PASS"
            - name: LVENV_REDIS_PORT
              value: "6379"
            - name: LVENV_MAIL_DRIVER
              value: "smtp"
            - name: LVENV_MAIL_HOST
              value: "$MAIL_HOST"
            - name: LVENV_MAIL_PORT
              value: "$MAIL_PORT"
            - name: LVENV_MAIL_USERNAME
              value: "$MAIL_USERNAME"
            - name: LVENV_MAIL_PASSWORD
              value: "$MAIL_PASSWORD"
            - name: LVENV_MAIL_ENCRYPTION
              value: "$MAIL_ENCRYPTION"
            - name: LVENV_PUSHER_APP_ID
              value: ""
            - name: LVENV_PUSHER_APP_KEY
              value: ""
            - name: LVENV_PUSHER_APP_SECRET
              value: ""
            - name: LVENV_REDIS_CLIENT
              value: "phpredis"
            - name: LVENV_JWT_SECRET
              value: "$JWT_SECRET"
            - name: LVENV_PADDLE_VENDOR_ID
              value: ""
            - name: LVENV_PADDLE_VENDOR_AUTH_CODE
              value: ""
            - name: LVENV_PADDLE_ENV
              value: "sandbox"
            - name: LVENV_WAVE_DOCS
              value: "true"
            - name: LVENV_WAVE_DEMO
              value: "true"
            - name: LVENV_WAVE_BAR
              value: "true"
            - name: LVENV_TRUSTED_PROXIES
              value: "$TRUSTED_PROXIES"
            - name: LVENV_ASSET_URL
              value: " "
          volumeMounts:
            - mountPath: /var/www/site
              name: wave-volume
      volumes:
        - name: wave-volume
          hostPath:
            path: $WAVE_DIR
```

You'll see its quiet similar to the previous composer deployment.

We mount the directory with our code in via a Volume.

```yaml
    volumeMounts:
      - mountPath: /var/www/site
        name: wave-volume
volumes:
  - name: wave-volume
    hostPath:
      path: $WAVE_DIR
```

We set the enviroment up with environmental variables.

```yaml
env:
  - name: ENABLE_HORIZON
    value: "FALSE"
  - name: CRONTAB_ACTIVE
    value: "TRUE"
```

The one big difference is the annotations metioned to let Keel know how we want it to update the 
image.

```yaml
annotations:
  keel.sh/policy: force
  keel.sh/trigger: poll
  keel.sh/pollSchedule: "@every 5m"
```

##### Service

Next we create a service allowing the application to be visable to the cluster.

This is mainly needed so that Traefik can send traffic to the application.

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: wave-lv-example
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: wave-lv-example
```


##### Ingres

Finally, we add the ingress route.

```yaml
kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  name: wave-lv-example
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.middlewares: traefik-traefik-compress@kubernetescrd
    cert-manager.io/cluster-issuer: letsencrypt-production
    traefik.ingress.kubernetes.io/redirect-regex: "^https://www.$DOMAIN/(.*)"
    traefik.ingress.kubernetes.io/redirect-replacement: "https://$DOMAIN/$1"
spec:
  tls:
    - hosts:
        - $DOMAIN
        - www.$DOMAIN
      secretName: wave-cert-tls
  rules:
    - host: $DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: wave-lv-example
                port:
                  number: 80
    - host: www.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: wave-lv-example
                port:
                  number: 80
```

This follows similar patters to the previous ingres routes.

The only big difference is redirecting the www domain to the route domain.

This isn't really needed for dev but it s a good idea to do for productions.

```yaml
    traefik.ingress.kubernetes.io/redirect-regex: "^https://www.$DOMAIN/(.*)"
    traefik.ingress.kubernetes.io/redirect-replacement: "https://$DOMAIN/$1"
```

##### Apply

Now we just need to apply this to bring our application up.

```shell
cat ./wave/wave.deploy.tmpl.yaml | envsubst > ./wave/wave.deploy.env.yaml
kubectl apply --namespace wave -f ./wave/wave.deploy.env.yaml
```

#### Redis commander

As we did previously to make development easier I've added Redis Commander.

```shell
cat ./wave/rediscommander.deploy.tmpl.yaml | envsubst > ./wave/rediscommander.deploy.env.yaml
kubectl apply --namespace wave -f ./wave/rediscommander.deploy.env.yaml
```


#### Final setup

Ok now we just need to run our migrations and DB seed.

This could be automated via job but for simplicity we'll do it by hand.

First run

```shell
kubectl exec --tty --namespace wave -i $(kubectl get pods --namespace wave | grep wave-lv-example | awk '{print $1}') -- bash -c 'su - www-data'
```

This basically gets the pod for the Laravel application then execs into it.

Once we are in we just need run the following to update everything.

```shell
cd /var/www/site
yes | php artisan migrate
yes | php artisan db:seed
```

You should now be able to access your development site at 

https://dev.example.com

## Production setup

We'll next cover the production setup. 

For this we'll be using Digital Oceans kubernetes.

We'll set this up via Terraform and then do systems helm setup via Terraform as well.

### Terraform

I've tried to make most the tunable or things like token into variables.

These can be found in these files.

* [./infra/terraform/variables.tf](./infra/terraform/variables.tf)
* [./infra/terraform/variables_dns.tf](./infra/terraform/variables_dns.tf)
* [./infra/terraform/variables_certs.tf](./infra/terraform/variables_certs.tf)
* [./infra/terraform/variables_helm.tf](./infra/terraform/variables_helm.tf)
* [./infra/terraform/variables_kubernetes.tf](./infra/terraform/variables_kubernetes.tf)
* [./infra/terraform/variables_wave.tf](./infra/terraform/variables_wave.tf)

#### Terraform Versions

We start by specifying all the versions of the plugins we will be using.
[./infra/terraform/versions.tf](./infra/terraform/versions.tf)
```hcl
terraform {
  required_providers {

    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.9"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.2"
    }

    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.11.1"
    }

    helm = {
      source = "hashicorp/helm"
      version = "~> 2.1"
    }
  }

  required_version = "~> 1.0.0"
}
```

#### Create Kubernetes Cluster

Next we want to set up the kubernetes cluster.

We'll be using the [DigtalOcean provider](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs)

First we log in to the provider with the DigitalOcean token.

[./infra/terraform/do_account.tf](./infra/terraform/do_account.tf)
```hcl
provider "digitalocean" {
  token = var.do_token
}
```

Next we create the kubernetes cluster.

[./infra/terraform/do_kubernetes.tf](./infra/terraform/do_kubernetes.tf)
```hcl
resource "digitalocean_kubernetes_cluster" "example" {
  name    = var.kubernetes_cluster_name
  region  = var.region
  version = var.kubernetes_version
  auto_upgrade = var.kubernetes_auto_upgrade
  surge_upgrade = var.kubernetes_surge_upgrade

  node_pool {
    name       = var.kubernetes_cluster_autoscale_pool_name
    size       = var.server_size
    auto_scale = var.kubernetes_auto_scale
    min_nodes  = var.kubernetes_min_nodes
    max_nodes  = var.kubernetes_max_nodes
    node_count = var.kubernetes_default_nodes
  }
}
```

#### Setup Kubernetes

We then use the [Kubernetes provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs).

First we tell the provider how to access the cluster using the setting generated while creating
the cluster.

[./infra/terraform/kubernetes.tf](./infra/terraform/kubernetes.tf)
```hcl
provider "kubernetes" {
  host             = digitalocean_kubernetes_cluster.example.endpoint
  token            = digitalocean_kubernetes_cluster.example.kube_config[0].token

  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
}
```

#### Setup Kubectl

The Hashicorp Kubernetes provider only covers the standard kubernetes resources.

So to hands any others we are using the [Kubectl provider](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs).

This allows us to apply standard Yaml files for anything not covered.

The configuration is very similar.

[./infra/terraform/kubectl.tf](./infra/terraform/kubectl.tf)
```hcl
provider "kubectl" {
  host             = digitalocean_kubernetes_cluster.example.endpoint
  token            = digitalocean_kubernetes_cluster.example.kube_config[0].token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
  load_config_file       = false
}
```

#### Setup Helm

We also then set up the [Helm provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)

[./infra/terraform/helm.tf](./infra/terraform/helm.tf)
```hcl
provider "helm" {
  kubernetes {
    host = digitalocean_kubernetes_cluster.example.endpoint
    token = digitalocean_kubernetes_cluster.example.kube_config[0].token

    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
  }
}
```

#### Setup Helm Dashboard

[./infra/terraform/helm-dashboard.tf](./infra/terraform/helm-dashboard.tf)
```hcl
resource "kubernetes_service_account" "dashboard-admin" {
  automount_service_account_token = true

  metadata {
    name      = "dashboard-admin-sa"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "dashboard-admin-clusterrolebinding" {
  metadata {
    name = "dashboard-admin-rb"
  }
  role_ref {
    kind      = "ClusterRole"
    name      = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "User"
    name      = "dashboard-admin"
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "dashboard-admin-sa"
    namespace = "kube-system"
  }
  subject {
    kind      = "Group"
    name      = "system:masters"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "helm_release" "kubernetes-dashboard" {
  name = "kubernetes-dashboard"
  namespace = "kube-system"
  repository = "https://kubernetes.github.io/dashboard"
  chart = "kubernetes-dashboard"
  version = "4.2.0"
  set {
    name  = "metricsScraper.enabled"
    value = "true"
  }
  set {
    name  = "metrics-server.enabled"
    value = "true"
  }
  set {
    name  = "metrics-server.args"
    value = "{--kubelet-preferred-address-types=InternalIP}"
  }
}
```

You'll see as we did for local we fist create a service account and and give it the correct roles.

We then do a helm install of the dashboard.

If you compare it to the helm install for the previous version you'll see that they match quiet 
closely.

#### Setup Helm Monitoring

[./infra/terraform/helm-dashboard.tf](./infra/terraform/helm-monitoring.tf)
```hcl
locals {
  monitoring_name_space = "monitoring"
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    annotations = {
      name = local.monitoring_name_space
    }
    name = local.monitoring_name_space
  }
}

data "template_file" "prometheus_operator_values" {
  template = file("./kube_files/monitoring/prometheus-values.tmpl.yaml")
  vars = {
    grafana_admin_password = var.grafana_admin_password
    dns_domain = var.dns_domain
  }
}

resource "helm_release" "prometheus-operator" {
  name = "prometheus-operator"
  namespace = local.monitoring_name_space
  repository = "https://prometheus-community.github.io/helm-charts"
  chart = "kube-prometheus-stack"
  version = "16.1.0"

  values = [
    data.template_file.prometheus_operator_values.rendered
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
  ]
}

resource "kubernetes_ingress" "prometheus-ingres" {
  metadata {
    name = "prometheus"
    namespace = local.monitoring_name_space
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls" = "true"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-traefik-compress@kubernetescrd,traefik-traefik-auth@kubernetescrd"
      "cert-manager.io/cluster-issuer" = "letsencrypt-dns-production"
      "external-dns.alpha.kubernetes.io/hostname" = "prometheus.${var.dns_domain}, alertmanager.${var.dns_domain}"
    }
  }

  spec {
    rule {
      host = "prometheus.${var.dns_domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "prometheus-operated"
            service_port = 9090
          }
        }
      }
    }
    rule {
      host = "alertmanager.${var.dns_domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "alertmanager-operated"
            service_port = 9093
          }
        }
      }
    }
    tls {
      hosts = [
        "prometheus.${var.dns_domain}",
        "alertmanager.${var.dns_domain}"
      ]
      secret_name = "prometheus-cert-tls"
    }
  }
  depends_on = [
    kubernetes_namespace.monitoring,
    kubectl_manifest.traefik-middleware-auth,
    kubectl_manifest.traefik-middleware-compress,
    helm_release.cert-manager,
    helm_release.traefik,
  ]
}

resource "kubernetes_ingress" "grafana-ingres" {
  metadata {
    name = "grafana"
    namespace = local.monitoring_name_space
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls" = "true"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-traefik-compress@kubernetescrd"
      "cert-manager.io/cluster-issuer" = "letsencrypt-dns-production"
      "external-dns.alpha.kubernetes.io/hostname" = "grafana.${var.dns_domain}"
    }
  }

  spec {
    rule {
      host = "grafana.${var.dns_domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "prometheus-operator-grafana"
            service_port = 80
          }
        }
      }
    }
    tls {
      hosts = [
        "grafana.${var.dns_domain}"
      ]
      secret_name = "grafana-cert-tls"
    }
  }
  depends_on = [
    kubernetes_namespace.monitoring,
    kubectl_manifest.traefik-middleware-auth,
    kubectl_manifest.traefik-middleware-compress,
    helm_release.cert-manager,
    helm_release.traefik,
  ]
}
```

We also follow a similar proces to what we did for the local development enviroment.

We first create the namespace.

Next we create the values files via ```template_file```. Previously we did this with envsubst.

We then install the ```prometheus-operator``` helm chart. You'll also notice we use the ```depends_on```
To ensure its only run after the namespace is created.

Next we add the ingres routes for the ```prometheus-operator``` endpoints.

Though be aware these require that you have Traefik activated before they can run. To get around 
this we also use the ```depends_on``` to say we need the helm traefik chart to be installed 
before running this.

You'll see this points the ```helm_release.traefik``` which we cover in the Traefik helm file.

#### Setup Helm ExternalDns

[./infra/terraform/helm-external-dns.tf](./infra/terraform/helm-external-dns.tf)
```hcl
locals {
  external_dns_name_space = "external-dns"
}

resource "kubernetes_namespace" "external-dns" {
  metadata {
    annotations = {
      name = local.external_dns_name_space
    }

    name = local.external_dns_name_space
  }
}

resource "kubernetes_secret" "external-dns-cloudflare-api-token" {
  metadata {
    name = "cloudflare-apikey"
    namespace = local.external_dns_name_space
  }

  data = {
    cloudflare_api_token = var.cloudflare_api_token
  }

  type = "Opaque"
  depends_on = [
    kubernetes_namespace.external-dns,
  ]
}

resource "helm_release" "external-dns" {
  name = "external-dns"
  namespace = local.external_dns_name_space
  repository = "https://charts.bitnami.com/bitnami"
  chart = "external-dns"
  version = "5.0.3"

//  values = [
//    data.template_file.prometheus_operator_values.rendered
//  ]

  set {
    name = "sources"
    value = "{service,ingress}"
  }

  set {
    name = "interval"
    value = "3m"
  }

  set {
    name = "registry"
//    value = "noop"
    value = "txt"
  }

  set {
    name = "txtOwnerId"
    value = "lvexample"
  }

  set {
    name = "txtPrefix"
    value = "lvexample."
  }

  set {
    name = "provider"
    value = "cloudflare"
  }

  set {
    name = "cloudflare.secretName"
    value = "cloudflare-apikey"
  }

  set {
    name = "domainFilters"
    value = "{${var.dns_domain}}"
  }

  set {
    name = "cloudflare.proxied"
    value = "false"
  }

  set {
    name = "metrics.enabled"
    value = "true"
  }

  set {
    name = "policy"
    value = "sync"
  }

  set {
    name = "rbac.create"
    value = "true"
  }

  set {
    name = "rbac.clusterRole"
    value = "true"
  }

  set {
    name = "logLevel"
//    value = "info"
    value = "debug"
  }

  depends_on = [
    kubernetes_secret.external-dns-cloudflare-api-token,
    kubernetes_namespace.external-dns,
  ]
}
```

For local, we didn't add [ExternalDns](https://github.com/kubernetes-sigs/external-dns).

Else every user spinning up a enviroment would have been adding DNS entries. 

So we just did the wild card entry pointing at ```127.0.0.1```.

We are now setting up production it makes our life easier to set up ExternalDNS.

This will automatically add DNS entries from our ingres routes pointing at the external IP of 
the cluster.

Looking at the HCL config you'll see it follows similar steps to most of the installations.

We first create a namespace.

Then we add the Cloudflare api token as a secret. This is the same as for CertManager.

We then install the ExternalDns helm chart.

Providing its configuration. Things like that we are using CloudFlare and where to find the secret.

#### Setup Helm CertManager

[./infra/terraform/helm-cert-manager.tf](./infra/terraform/helm-cert-manager.tf)
```hcl
locals {
  cert_manager_name_space = "cert-manager"
}

locals {
  cert_email = "cert@${var.dns_domain}"
}

resource "kubernetes_namespace" "cert-manager" {
  metadata {
    annotations = {
      name = local.cert_manager_name_space
    }

    labels = {
      "certmanager.k8s.io/disable-validation" = "true"
    }

    name = local.cert_manager_name_space
  }
}

resource "kubernetes_secret" "cert-manager-cloudflare-api-token" {
  metadata {
    name = "cloudflare-apikey"
    namespace = local.cert_manager_name_space
  }

  data = {
    cloudflare_api_token = var.cloudflare_api_token
  }

  type = "Opaque"
  depends_on = [
    kubernetes_namespace.cert-manager,
    helm_release.cert-manager,
  ]
}

resource "helm_release" "cert-manager" {
  name = "cert-manager"
  namespace = local.cert_manager_name_space
  repository = "https://charts.jetstack.io"
  chart = "cert-manager"
  version = "1.3.1"

  set {
    name = "installCRDs"
    value = "true"
  }

  set {
    name = "prometheus.enabled"
    value = "true"
  }

  depends_on = [
    kubernetes_namespace.cert-manager,
    helm_release.prometheus-operator,
  ]
}

data "template_file" "acme_dns_production" {
  template = file("./kube_files/cert/acme-dns-production.tmpl.yaml")
  vars = {
    cert_email = local.cert_email
  }
}

resource "kubectl_manifest" "acme-dns-prod-config" {
  override_namespace = local.cert_manager_name_space
  yaml_body = data.template_file.acme_dns_production.rendered
  depends_on = [
    kubernetes_namespace.cert-manager,
    helm_release.cert-manager,
    kubernetes_secret.cert-manager-cloudflare-api-token,
  ]
}

data "template_file" "acme_dns_staging" {
  template = file("./kube_files/cert/acme-dns-staging.tmpl.yaml")
  vars = {
    cert_email = local.cert_email
  }
}

resource "kubectl_manifest" "acme_dns_staging_config" {
  override_namespace = local.cert_manager_name_space
  yaml_body = data.template_file.acme_dns_staging.rendered
  depends_on = [
    kubernetes_namespace.cert-manager,
    helm_release.cert-manager,
    kubernetes_secret.cert-manager-cloudflare-api-token,
  ]
}
```

Next we install CertManager. Following the same pattern as the previous installs.

#### Setup Helm Traefik

[./infra/terraform/helm-traefik.tf](./infra/terraform/helm-traefik.tf)
```hcl
locals {
  traefik_name_space = "traefik"
}

resource "kubernetes_namespace" "traefik" {
  metadata {
    annotations = {
      name = local.traefik_name_space
    }
    name = local.traefik_name_space
  }
}

resource "helm_release" "traefik" {
  name = "traefik"
  namespace = local.traefik_name_space
  repository = "https://containous.github.io/traefik-helm-chart"
  chart = "traefik"
  version = "9.1.1"

  values = [
    file("./kube_files/traefik/traefik-values.yaml")
  ]

  depends_on = [
    kubernetes_namespace.traefik,
  ]
}

resource "kubernetes_secret" "traefik_auth" {
  metadata {
    name = "traefik-authsecret"
    namespace = local.traefik_name_space
  }

  data = {
    users = var.traefik_auth
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace.traefik,
  ]
}

resource "kubernetes_service" "traefik-web-ui" {
  metadata {
    name = "traefik-web-ui"
    namespace = local.traefik_name_space
  }
  spec {
    selector = {
      "app.kubernetes.io/instance" = "traefik"
      "app.kubernetes.io/instance" = "traefik"
    }
    port {
      name = "web"
      port = 9000
      target_port = 9000
    }
  }

  depends_on = [
    kubernetes_namespace.traefik,
    helm_release.traefik,
  ]
}

resource "kubectl_manifest" "traefik-middleware-auth" {
  override_namespace = local.traefik_name_space
  yaml_body = file("./kube_files/traefik/traefik-middleware-auth.yaml")
  depends_on = [
    kubernetes_namespace.traefik,
    helm_release.traefik,
    kubernetes_secret.traefik_auth,
  ]
}

resource "kubectl_manifest" "traefik-middleware-compress" {
  override_namespace = local.traefik_name_space
  yaml_body = file("./kube_files/traefik/traefik-middleware-compress.yaml")
  depends_on = [
    kubernetes_namespace.traefik,
    helm_release.traefik,
  ]
}

resource "kubernetes_ingress" "traefik-ingres" {
  metadata {
    name = "traefik"
    namespace = local.traefik_name_space
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls" = "true"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-traefik-compress@kubernetescrd,traefik-traefik-auth@kubernetescrd"
      "cert-manager.io/cluster-issuer" = "letsencrypt-dns-production"
      "external-dns.alpha.kubernetes.io/hostname" = "traefik.${var.dns_domain}"
    }
  }

  spec {
    rule {
      host = "traefik.${var.dns_domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "traefik-web-ui"
            service_port = 9000
          }
        }
      }
    }
    tls {
      hosts = [
        "traefik.${var.dns_domain}"
      ]
      secret_name = "traefik-cert-tls"
    }
  }
  depends_on = [
    kubernetes_namespace.traefik,
    kubectl_manifest.traefik-middleware-auth,
    kubectl_manifest.traefik-middleware-compress,
    helm_release.cert-manager,
    helm_release.traefik,
  ]
}
```

The main difference with this install to the previous one is the ```external-dns.alpha.kubernetes.io/hostname```
annotation. This is how we let ExternalDNS know which DNS entries to add.

#### Setup Helm Keel

[./infra/terraform/helm-keel.tf](./infra/terraform/helm-keel.tf)
```hcl
locals {
  keel_name_space = "keel"
}

resource "kubernetes_namespace" "keel" {
  metadata {
    annotations = {
      name = local.keel_name_space
    }
    name = local.keel_name_space
  }
}

data "template_file" "keel_values" {
  template = file("./kube_files/keel/keel-values.tmpl.yml")
  vars = {
    traefik_username = var.traefik_username
    traefik_password = var.traefik_password
  }
}

resource "helm_release" "keel" {
  name = "keel"
  namespace = local.keel_name_space
  repository = "https://charts.keel.sh"
  chart = "keel"
  version = "0.9.8"
  values = [
    data.template_file.keel_values.rendered
  ]

  depends_on = [
    kubernetes_namespace.keel,
  ]
}

resource "kubernetes_ingress" "keel-ingres" {
  metadata {
    name = "keel"
    namespace = local.keel_name_space
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls" = "true"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-traefik-compress@kubernetescrd,traefik-traefik-auth@kubernetescrd"
      "cert-manager.io/cluster-issuer" = "letsencrypt-dns-production"
      "external-dns.alpha.kubernetes.io/hostname" = "keel.${var.dns_domain}"
    }
  }

  spec {
    rule {
      host = "keel.${var.dns_domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "keel"
            service_port = 9300
          }
        }
      }
    }
    tls {
      hosts = [
        "keel.${var.dns_domain}"
      ]
      secret_name = "keel-cert-tls"
    }
  }
  depends_on = [
    kubernetes_namespace.keel,
    kubectl_manifest.traefik-middleware-auth,
    kubectl_manifest.traefik-middleware-compress,
    helm_release.cert-manager,
    helm_release.traefik,
    helm_release.keel,
  ]
}
```

#### Setup Helm Keel

[./infra/terraform/helm-elastic.tf](./infra/terraform/helm-elastic.tf)
```hcl
locals {
  elastic_name_space = "elastic"
}

resource "kubernetes_namespace" "elastic" {
  metadata {
    annotations = {
      name = local.elastic_name_space
    }
    name = local.elastic_name_space
  }
}

resource "helm_release" "elastic" {
  name = "elasticsearch"
  namespace = local.elastic_name_space
  repository = "https://helm.elastic.co"
  chart = "elasticsearch"
  version = "7.13.1"

  values = [
    file("./kube_files/elastic/elasticsearch-values.yaml")
  ]

  depends_on = [
    kubernetes_namespace.elastic,
  ]
}

resource "helm_release" "kibana" {
  name = "kibana"
  namespace = local.elastic_name_space
  repository = "https://helm.elastic.co"
  chart = "kibana"
  version = "7.13.1"

  set {
    name = "replicas"
    value = "1"
  }
  set {
    name = "ingress.enabled"
    value = "false"
  }

  depends_on = [
    kubernetes_namespace.elastic,
    helm_release.elastic,
  ]
}

resource "kubernetes_ingress" "elastic-ingres" {
  metadata {
    name = "kibana"
    namespace = local.elastic_name_space
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls" = "true"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-traefik-compress@kubernetescrd,traefik-traefik-auth@kubernetescrd"
      "cert-manager.io/cluster-issuer" = "letsencrypt-dns-production"
      "external-dns.alpha.kubernetes.io/hostname" = "kibana.${var.dns_domain}"
    }
  }

  spec {
    rule {
      host = "kibana.${var.dns_domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "kibana-kibana"
            service_port = 5601
          }
        }
      }
    }
    tls {
      hosts = [
        "kibana.${var.dns_domain}"
      ]
      secret_name = "kibana-cert-tls"
    }
  }
  depends_on = [
    kubectl_manifest.traefik-middleware-auth,
    kubectl_manifest.traefik-middleware-compress,
    helm_release.cert-manager,
    helm_release.traefik,
    helm_release.elastic,
  ]
}

resource "helm_release" "metricbeat" {
  name = "metricbeat"
  namespace = local.elastic_name_space
  repository = "https://helm.elastic.co"
  chart = "metricbeat"
  version = "7.13.1"
  depends_on = [
    kubernetes_namespace.elastic,
    helm_release.elastic,
  ]
}

resource "helm_release" "filebeat" {
  name = "filebeat"
  namespace = local.elastic_name_space
  repository = "https://helm.elastic.co"
  chart = "filebeat"
  version = "7.13.1"
  values = [
    file("./kube_files/elastic/filebeat-values.yaml")
  ]
  depends_on = [
    kubernetes_namespace.elastic,
    helm_release.elastic,
  ]
}
```

As we will be running multiple versions of our Laravel application, it becomes harder to watch 
the logs of every container.

So we are adding the ELK stack and piping all logs from Kubernetes to it.

#### Setup Laravel Application

Now that we have once again set up the enviroment.

We'll do the deployment of the Laravel Applications.

```hcl
locals {
  wave_name_space = "wave"
}

resource "kubernetes_namespace" "wave_name_space" {
  metadata {
    annotations = {
      name = local.wave_name_space
    }

    name = local.wave_name_space
  }
}

resource "kubernetes_secret" "wave_docker_registry_login" {
  metadata {
    name = "docker-registry-credential"
  }

  data = {
    ".dockerconfigjson" = <<DOCKER
{
  "auths": {
    "${var.wave_registry_server}": {
      "auth": "${base64encode("${var.wave_registry_username}:${var.wave_registry_password}")}"
    }
  }
}
DOCKER
  }

  type = "kubernetes.io/dockerconfigjson"
  depends_on = [
    kubernetes_namespace.wave_name_space,
  ]
}

resource "kubernetes_secret" "wave-secrets" {
  metadata {
    name = "wave-secrets"
    namespace = local.wave_name_space
  }

  data = {
    "postgresql-password" = var.wave_db_password
    "redis-password" = var.wave_redis_password
    "wave_app_mail_password" = var.wave_app_mail_password
    "wave_app_jwt_secret" = var.wave_app_jwt_secret
    "wave_app_key" = var.wave_app_key
  }

  type = "Opaque"
  depends_on = [
    kubernetes_namespace.wave_name_space,
  ]
}

data "template_file" "wave_postgres" {
  template = file("./kube_files/wave/postgresql-values.tmpl.yaml")
  vars = {
    wave_db_replica_count = var.wave_db_replica_count
    wave_db_name = var.wave_db_name
    wave_db_user = var.wave_db_user
    wave_db_password = var.wave_db_password
    wave_db_repmgr_password = var.wave_db_password
    wave_db_pgpool_admin_password = var.wave_db_password
  }
}

resource "helm_release" "wave-postgresql-ha" {
  name = "postgresql-ha"
  namespace = local.wave_name_space
  repository = "https://charts.bitnami.com/bitnami"
  chart = "postgresql-ha"
  version = "7.6.0"

  values = [
    data.template_file.wave_postgres.rendered
  ]

  depends_on = [
    kubernetes_namespace.wave_name_space,
    kubernetes_secret.wave-secrets,
    helm_release.elastic,
  ]
}

data "template_file" "wave_redis" {
  template = file("./kube_files/wave/redis-values.tmp.yaml")
  vars = {
    wave_redis_replica_count = var.wave_redis_replica_count
  }
}

resource "helm_release" "wave-redis" {
  name = "redis"
  namespace = local.wave_name_space
  repository = "https://charts.bitnami.com/bitnami"
  chart = "redis"
  version = "14.3.3"

  values = [
    data.template_file.wave_redis.rendered
  ]

  depends_on = [
    kubernetes_namespace.wave_name_space,
    kubernetes_secret.wave-secrets,
    helm_release.elastic,
  ]
}

resource "kubernetes_deployment" "wave-lv-example" {
  metadata {
    name = "wave-lv-example"
    namespace = local.wave_name_space
    annotations = {
      "keel.sh/policy": "force"
      "keel.sh/trigger": "poll"
      "keel.sh/pollSchedule": "@every 5m"
    }
  }
  spec {
    replicas = var.wave_app_replicas

    selector {
      match_labels = {
        "app" = "wave-lv-example"
      }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge = "1"
        max_unavailable = "50%"
      }
    }

    template {
      metadata {
        labels = {
          app = "wave-lv-example"
        }
        annotations = {
          "co.elastic.logs/enabled" = "true"
          "co.elastic.logs/json.keys_under_root" = "true"
          "co.elastic.logs/json.message_key" = "message"
          "co.elastic.logs/json.overwrite_keys" = "true"
        }
      }

      spec {
        image_pull_secrets {
          name = "docker-registry-credential"
        }
        container {
          image = "haakco/deploying-laravel-app-ubuntu-20.04-php7.4-lv-wave:latest"
          name = "wave-lv-example"

          port {
            container_port = 80
          }
          env {
            name = "LVENV_JWT_SECRET"
            value_from {
              secret_key_ref {
                name = "wave-secrets"
                key = "wave_app_jwt_secret"
              }
            }
          }
          env {
            name = "LVENV_APP_KEY"
            value_from {
              secret_key_ref {
                name = "wave-secrets"
                key = "wave_app_key"
              }
            }
          }
          env {
            name = "LVENV_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = "wave-secrets"
                key = "postgresql-password"
              }
            }
          }
          env {
            name = "LVENV_REDIS_PASSWORD"

            value_from {
              secret_key_ref {
                name = "wave-secrets"
                key = "redis-password"
              }
            }
          }
          env {
            name = "LVENV_MAIL_PASSWORD"
            value_from {
              secret_key_ref {
                name = "wave-secrets"
                key = "wave_app_mail_password"
              }
            }
          }

          env {
            name = "ENABLE_HORIZON"
            value = "FALSE"
          }

          env {
            name = "CRONTAB_ACTIVE"
            value = "TRUE"
          }

          env {
            name = "GEN_LV_ENV"
            value = "TRUE"
          }
          env {
            name = "LVENV_APP_NAME"
            value = var.wave_app_name
          }
          env {
            name = "LVENV_APP_ENV"
            value = var.wave_app_name_env
          }
          env {
            name = "LVENV_APP_DEBUG"
            value = var.wave_app_debug
          }
          env {
            name = "LVENV_APP_LOG_LEVEL"
            value = var.wave_app_log_level
          }
          env {
            name = "LVENV_APP_URL"
            value = "https://${var.dns_domain}"
          }
          env {
            name = "LVENV_DB_CONNECTION"
            value = "pgsql"
          }
          env {
            name = "LVENV_DB_HOST"
            value = "postgresql-ha-pgpool.wave.svc.cluster.local"
          }
          env {
            name = "LVENV_DB_PORT"
            value = "5432"
          }
          env {
            name = "LVENV_DB_DATABASE"
            value = var.wave_db_name
          }
          env {
            name = "LVENV_DB_USERNAME"
            value = var.wave_db_user
          }
          env {
            name = "LVENV_BROADCAST_DRIVER"
            value = "log"
          }
          env {
            name = "LVENV_CACHE_DRIVER"
            value = "redis"
          }
          env {
            name = "LVENV_SESSION_DRIVER"
            value = "redis"
          }
          env {
            name = "LVENV_SESSION_LIFETIME"
            value = "9999"
          }
          env {
            name = "LVENV_QUEUE_DRIVER"
            value = "redis"
          }
          env {
            name = "LVENV_REDIS_HOST"
            value = "redis-master.wave.svc.cluster.local"
          }
          env {
            name = "LVENV_REDIS_PORT"
            value = "6379"
          }
          env {
            name = "LVENV_MAIL_DRIVER"
            value = "smtp"
          }
          env {
            name = "LVENV_MAIL_HOST"
            value = var.wave_app_mail_host
          }
          env {
            name = "LVENV_MAIL_PORT"
            value = var.wave_app_mail_port
          }
          env {
            name = "LVENV_MAIL_USERNAME"
            value = var.wave_app_mail_username
          }
          env {
            name = "LVENV_MAIL_ENCRYPTION"
            value = var.wave_app_mail_encryption
          }
          env {
            name = "LVENV_PUSHER_APP_ID"
            value = ""
          }
          env {
            name = "LVENV_PUSHER_APP_KEY"
            value = ""
          }
          env {
            name = "LVENV_PUSHER_APP_SECRET"
            value = ""
          }
          env {
            name = "LVENV_REDIS_CLIENT"
            value = "phpredis"
          }
          env {
            name = "LVENV_PADDLE_VENDOR_ID"
            value = ""
          }
          env {
            name = "LVENV_PADDLE_VENDOR_AUTH_CODE"
            value = ""
          }
          env {
            name = "LVENV_PADDLE_ENV"
            value = "sandbox"
          }
          env {
            name = "LVENV_WAVE_DOCS"
            value = "true"
          }
          env {
            name = "LVENV_WAVE_DEMO"
            value = "true"
          }
          env {
            name = "LVENV_WAVE_BAR"
            value = "true"
          }
          env {
            name = "LVENV_TRUSTED_PROXIES"
            value = var.wave_app_trusted_proxies
          }
          env {
            name = "LVENV_ASSET_URL"
            value = " "
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.wave_name_space,
    kubernetes_secret.wave-secrets,
    helm_release.wave-postgresql-ha,
    helm_release.wave-redis,
    helm_release.elastic,
  ]
}

resource "kubernetes_service" "wave-lv-example" {
  metadata {
    name = "wave-lv-example"
    namespace = local.wave_name_space
  }
  spec {
    selector = {
      app = "wave-lv-example"
    }
    port {
      port = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
  depends_on = [
    kubernetes_namespace.wave_name_space,
    kubernetes_secret.wave-secrets,
    helm_release.wave-postgresql-ha,
    helm_release.wave-redis,
    kubernetes_deployment.wave-lv-example,
  ]
}

resource "kubernetes_ingress" "wave-lv-example-ingres" {
  metadata {
    name = "wave-lv-example"
    namespace = local.wave_name_space
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls" = "true"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-traefik-compress@kubernetescrd"
      "cert-manager.io/cluster-issuer" = "letsencrypt-dns-production"
      "external-dns.alpha.kubernetes.io/hostname" = "${var.dns_domain},www.${var.dns_domain}"
      "traefik.ingress.kubernetes.io/redirect-regex" = "^https://www.${var.dns_domain}/(.*)"
      "traefik.ingress.kubernetes.io/redirect-replacement" = "https://${var.dns_domain}/$1"
    }
  }

  spec {
    rule {
//      host = "@.${var.dns_domain}"
      host = var.dns_domain
      http {
        path {
          path = "/"
          backend {
            service_name = "wave-lv-example"
            service_port = 80
          }
        }
      }
    }
    rule {
      host = "www.${var.dns_domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "wave-lv-example"
            service_port = 80
          }
        }
      }
    }
    tls {
      hosts = [
        var.dns_domain,
        "www.${var.dns_domain}"
      ]
      secret_name = "wave-cert-tls"
    }
  }
  depends_on = [
    kubernetes_namespace.wave_name_space,
    kubernetes_secret.wave-secrets,
    helm_release.wave-postgresql-ha,
    helm_release.wave-redis,
    kubernetes_deployment.wave-lv-example,
    kubernetes_service.wave-lv-example,
  ]
}
```

We follow a very similar setup and configuration compared to local.

Some of the differences is that we set up the PostgreSQL and Redis to be replicated.

We also move some of the more sensitive variables into Kubernetes secretes.

Then in the environmental configuration for the application we point to the secrets rather than 
just specifying them directly.

We also don't make the DB externally accessable.

If you need to get access to the Database I would recommend using [Kube Forwarder](https://www.
electronjs.org/apps/kube-forwarder).

Kube Forwarder can map ports from an application in your cluster to your local pc.

#### Terraform applying

As everything is in terraform to spin the fully working cluster and application up.

You just specify the relevant variables and run ```terraform apply```.

To make your life simpler there is [./infra/terraform/apply.sh](./infra/terraform/apply.sh) to 
do this.

So alter the file to your setting and then run.

```shell
./apply.sh
```

Then you just need to wait for everything to spin up.

The only steps left are to add the kubernetes cluster config and run the migrate and db seed.

First install [doctl](https://github.com/digitalocean/doctl).

Run the following to authenticate.

```shell
doctl auth init
```

As part of the output for the Terraform run it will print out the command similar to.

```shell
doctl kubernetes cluster kubeconfig save <id>
```

Run this to add the config for the cluster to your kubectl config.

Once you have done this you can just follow the same steps as for local.

First run

```shell
kubectl exec --tty --namespace wave -i $(kubectl get pods --namespace wave | grep wave-lv-example | awk '{print $1}') -- bash -c 'su - www-data'
```

This basically gets the pod for the Laravel application then execs into it.

Once we are in we just need run the following to update everything.

```shell
cd /var/www/site
yes | php artisan migrate
yes | php artisan db:seed
```

And you are done.

You should be able to access your application at https://example.com.


