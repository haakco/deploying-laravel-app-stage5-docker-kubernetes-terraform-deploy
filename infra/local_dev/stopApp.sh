#!/usr/bin/env bash
kubectl delete --namespace wave -f ./wave/wave.deploy.yaml

kubectl delete --namespace wave -f ./wave/dev-wave-cert-prod.yaml
helm uninstall --namespace wave wave-redis
helm uninstall --namespace wave wave-postgresql
kubectl delete namespace wave
