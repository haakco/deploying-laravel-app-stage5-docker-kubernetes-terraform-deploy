#!/usr/bin/env bash
kubectl delete --namespace wave -f ./wave/rediscommander.deploy.tmpl.yaml
kubectl delete --namespace wave -f ./wave/wave.deploy.tmpl.yaml
helm uninstall --namespace wave wave-redis
kubectl delete --namespace wave -f ./wave/redis-pvc.yaml
helm uninstall --namespace wave wave-postgresql
kubectl delete --namespace wave -f ./wave/postgresql-pvc.yaml
kubectl delete namespace wave
