#!/bin/bash

GCR_REPO=gcr.io/google_containers
MY_REPO=solomonlinux
REPO_NAME=gcr.io
GIT_REPO=git@github.com:solomonlinux/gcr.io.git
THREAD=5
DISK=70
IMAGE_LIST=`mktemp imagelist.XXX`

set -e

multi_thread_init(){
	# 声明管道名称,$$表示脚本当前运行的进程PID
	TMPFIFO=/tmp/$$.fifo
	# 创建管道
	mkfifo $TMPFIFO
	# 创建文件标识符5,这个数字可以为除0,1,2之外的所有未声明过的字符,以读写模式操作管道文件
	# 系统调用exec是以新的进程去替代原来的进程,但进程的PID保持不变,换句话说就是在调用进程内部执行一个可执行文件
	exec 5<>${TMPFIFO}
	rm -rf $TMPFIFO
	req $THREAD &>5
}

git_init(){
	# 这两个命令仅仅用于标识提交代码的开发者信息,可以随便设置;仅用于质量追踪到具体某一个人
	git config --global user.name "gaozhiqiang"
	git config --global user.email "1211348968@qq.com"
	git clone $GIT_REPO
	cd $REPO_NAME
}

git_commit(){
	echo
	local LINES=$(git status -s | wc -l)
	local TODAY=$(date "+%Y%m%d %H:%M:%S")
	if [ $LINES -gt 0 ]; then
		git add -A
		git commit 'Synchronizing completion at $TODAY'
		git push
	fi
}

add_repo(){
	echo
	cat > /etc/yum.repos.d/google-cloud-sdk.repo <<- EOF
		[google-cloud-sdk]
		name=Google Cloud SDK
		baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
		enabled=1
		gpgcheck=1
		repo_gpgcheck=1
		gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
		       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
	EOF
}

install_sdk(){
	echo
	yum -y install google-cloud-sdk
}

auth_sdk(){
	gcloud auth activate-service-account --key-file gcloud.config.json
}

image_list_create(){
	while read IMAGE; do
		# 如果镜像文件夹不存在就创建;如果镜像文件夹下存在latest文件则更名为latest.old文件
		[ -d $IMAGE ] || mkdir -p $IMAGE
		[ -f ${IMAGE}/latest ] && mv ${IMAGE}/latest{,.old}

		while read TAG; do
			if [ $TAG == "latest" && -f ${IMAGE}/latest.old ]; then
				DIGEST=$(gcloud container images list-tags $IMAGE --format="get(DIGEST)" --filter="tags=latest")
				echo $DIGEST > $IMAGE/latest
				diff ${IMAGE}/latest ${IMAGE}/latest.old &> /dev/null
				if [ $? -ne 0 ]; then
					#docker pull ${IMAGE}:latest
					echo ${IMAGE}:latest >> $IMAGE_LIST
				fi
			fi
			# 如果文件不存在,则说明镜像不存在,那么就创建文件并拉取镜像;否则就什么都不做
			if [ ! -f ${IMAGE}:${TAG} ]; then
				echo ${IMAGE}:${TAG} > ${IMAGE}/${TAG}
				#docker pull ${IMAGE}:${TAG}
				echo ${IMAGE}:${TAG} >> $IMAGE_LIST
			fi
			#echo ${IMAGE}:${TAG} >> list.txt &
		done < <(gcloud container images list-tags $IMAGE --format="get(TAGS)" --filter='tags:*' | sed 's#;#\n#g')

	done < <(gcloud container images list --repository=gcr.io/google_containers --format="value(NAME)")
}

image_pull(){
	echo "拉取镜像"
	echo
#	for ((i;i<=$THREAD;i++)); do
#		echo
#	done &>5
	while read LINE; do
		if [ $(df -h | awk -F " |%" '$NF=="/"{print $(NF-2)}') > $DISK ]; then
			#image_push
			touch test
			ls
		fi
		
		read -u5
		docker pull $LINE &
		exec &>5
	done < $IMAGE_LIST
	exec 5>&-
}

image_push(){
	echo "推送镜像"
	while read REPO TAG;do
		docker tag ${REPO}:${TAG} ${MY_REPO##*/}:${TAG}
		docker tag ${REPO}:${TAG} ${MY_REPO}/${REPO##*/}:${TAG}
		docker rmi ${REPO}:${TAG}
		docker push ${REPO}:${TAG}
		docker rmi ${MY_REPO}/${REPO##*/}:${TAG}
	done < <(docker images --format {{.Repository}}' '{{.Tag}})
}

generate_changelog(){
	echo
}

main(){
	git_init
	add_repo
	sdk_install
	sdk_auth
	multi_thread_init
	image_list_create
	image_pull
	generate_changelog
	git_commit
}

main
