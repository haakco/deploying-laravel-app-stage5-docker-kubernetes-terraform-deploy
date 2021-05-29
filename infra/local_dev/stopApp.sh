#!/usr/bin/env bash
kubectl delete --namespace wave -f ./wave/wave.deploy.env.yaml

#kubectl delete --namespace wave -f ./wave/dev-wave-cert-prod.env.yaml
helm uninstall --namespace wave wave-redis
#kubectl delete --namespace wave -f ./wave/redis-pvc.yaml
helm uninstall --namespace wave wave-postgresql
#kubectl delete --namespace wave -f ./wave/postgresql-pvc.yaml
#kubectl delete namespace wave
