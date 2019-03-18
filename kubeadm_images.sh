#!/bin/bash

# 使用时修改版本号以及版本所对应的镜像版本号
# 纯属方便使用的 --2019-03-18 22:05
VERSION=v1.12.2
MASTER_COMPONENTS='k8s.gcr.io/kube-proxy:v1.12.2
k8s.gcr.io/kube-apiserver:v1.12.2
k8s.gcr.io/kube-controller-manager:v1.12.2
k8s.gcr.io/kube-scheduler:v1.12.2
k8s.gcr.io/etcd:3.2.24
k8s.gcr.io/coredns:1.2.2
quay.io/coreos/flannel:v0.10.0-amd64
k8s.gcr.io/pause:3.1'
NODE_COMPONENTS='k8s.gcr.io/kube-proxy:v1.12.2
quay.io/coreos/flannel:v0.10.0-amd64
k8s.gcr.io/pause:3.1'

DOCKERHUB=solomonlinux

pull_image(){
	local SRC_IMAGE=$1
	local DOMAIN=${SRC_IMAGE%%/*}
	if [ $DOMAIN == "k8s.gcr.io" ]; then
		local DEST_IMAGE=${DOCKERHUB}/`echo ${SRC_IMAGE#*.} | tr / .`
		docker pull $DEST_IMAGE
		docker tag $DEST_IMAGE $SRC_IMAGE
	elif [ $DOMAIN == 'gcr.io' ]; then
		local DEST_IMAGE=${DOCKERHUB}/`echo ${SRC_IMAGE} | tr / .`
		docker pull $DEST_IMAGE
		docker tag $DEST_IMAGE $SRC_IMAGE
	elif [ $DOMAIN == 'quay.io' ]; then
		local DEST_IMAGE=${DOCKERHUB}/`echo $SRC_IMAGE | tr / .`
		docker pull $DEST_IMAGE
		docker tag $DEST_IMAGE $SRC_IMAGE
	else
		echo '不识别'
	fi
}

main(){
	for I in $MASTER_COMPONENTS; do
		pull_image $I
	done
	docker save -o kubernetes-${VERSION}-master-components.tar.gz $MASTER_COMPONENTS
	docker save -o kubernetes-${VERSION}-node-components.tar.gz $NODE_COMPONENTS
}
main
