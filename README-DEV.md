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

export DOMAIN=dev.example.com
export CERT_EMAIL="cert@${DOMAIN}"
export TRAEFIK_USERNAME='traefik'
export TRAEFIK_PASSWD='yairohchahKoo0haem0d'
export GRAFANA_ADMIN_PASSWORD=example_password

TRAEFIK_AUTH=$(docker run --rm -ti sineverba/htpasswd "${TRAEFIK_USERNAME}" "${TRAEFIK_PASSWD}" | openssl base64 -A)
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
export DOMAIN=dev.example.com
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
