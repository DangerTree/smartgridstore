#!/bin/bash
set -ex
docker build -t btrdb/kubernetes-controller-manager-rbd:1.5.2 .
docker push btrdb/kubernetes-controller-manager-rbd:1.5.2
