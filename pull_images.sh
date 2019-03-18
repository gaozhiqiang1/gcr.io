#!/bin/bash

# gcr.io.google_containers.etcd-arm64:3.3.10
# solomonlinux/gcr.io.google_containers.etcd-arm64:3.3.10
# quay.io/coreos/flannel:v0.10.0-amd64
# k8s.gcr.io/kube-proxy:v1.12.2

DOCKERHUB=solomonlinux

SRC_IMAGE=$1

DOMAIN=${1%%/*}
echo $DOMAIN
if [ $DOMAIN == "k8s.gcr.io" ]; then
	DEST_IMAGE=${DOCKERHUB}/`echo ${SRC_IMAGE#*.} | tr / .`
	docker pull $DEST_IMAGE
	#echo $DEST_IMAGE
	#echo $SRC_IMAGE
	docker tag $DEST_IMAGE $SRC_IMAGE
elif [ $DOMAIN == 'gcr.io' ]; then
	DEST_IMAGE=${DOCKERHUB}/`echo ${SRC_IMAGE} | tr / .`
elif [ $DOMAIN == 'quay.io' ]; then
	DEST_IMAGE=${DOCKERHUB}/`echo $SRC_IMAGE | tr / .`
	docker pull $DEST_IMAGE
	#echo $DEST_IMAGE
	#echo $SRC_IMAGE
	docker tag $DEST_IMAGE $SRC_IMAGE
else
	echo '不识别'
fi
