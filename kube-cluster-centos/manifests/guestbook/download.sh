#!/bin/bash
wget https://raw.githubusercontent.com/kubernetes/kubernetes/master/examples/guestbook/redis-master-controller.yaml
wget https://raw.githubusercontent.com/kubernetes/kubernetes/master/examples/guestbook/redis-master-service.yaml
wget https://raw.githubusercontent.com/kubernetes/kubernetes/master/examples/guestbook/redis-slave-controller.yaml
wget https://raw.githubusercontent.com/kubernetes/kubernetes/master/examples/guestbook/redis-slave-service.yaml
wget https://raw.githubusercontent.com/kubernetes/kubernetes/master/examples/guestbook/frontend-controller.yaml
wget https://raw.githubusercontent.com/kubernetes/kubernetes/master/examples/guestbook/frontend-service.yaml
kubectl create -f ./redis-master-controller.yaml
kubectl create -f ./redis-master-service.yaml
kubectl create -f ./redis-slave-controller.yaml
kubectl create -f ./redis-slave-service.yaml
kubectl create -f ./frontend-controller.yaml
kubectl create -f ./frontend-service.yaml

