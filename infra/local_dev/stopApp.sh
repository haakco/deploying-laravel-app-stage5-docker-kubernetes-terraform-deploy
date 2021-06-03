#!/usr/bin/env bash
kubectl delete --namespace wave -f ./wave/rediscommander.deploy.tmpl.yaml
kubectl delete --namespace wave -f ./wave/wave.deploy.tmpl.yaml

helm uninstall --namespace wave wave-redis
helm uninstall --namespace wave wave-postgresql
