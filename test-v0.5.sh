#!/bin/bash

# gcr.io与quay.io的名称空间
GCRIO_NS="google-appengine cloudsql-docker cloud-marketplace kubeflow-images-public spinnaker-marketplace istio-release kubernetes-e2e-test-images cloud-builders knative-releases cloud-datalab linkerd-io distroless google_containers kubernetes-helm runconduit google-samples k8s-minikube heptio-images tf-on-k8s-dogfood"
QUAYIO_NS="coreos wire calico prometheus outline weaveworks hellofresh kubernetes-ingress-controller replicated kubernetes-service-catalog 3scale"

# 我的dockerhub与github仓库
DOCKERHUB_REPO_NAME=solomonlinux
GITHUB_REPO_NAME=gcr.io
GITHUB_REPO_ADDR=git@github.com:solomonlinux/gcr.io.git

# 同步镜像之前打标使用的间隔符
INTERVAL=.

# 启动多少个线程同步
THREAD=3
# 磁盘容量超过多少时清理镜像
DISK=70

# 出错立即终止
set -e

# note1: travis-ci构建项目的最大时长是50min,超时之后项目构建终止
# note2: travis-ci如果长时间没有输出,那么10min之后会终止项目

multi_thread_init(){
	trap 'exec 5>&-;exec 5<&-;exit 0' 2
	# 声明管道名称,$$表示脚本当前运行的进程PID
	TMPFIFO=/tmp/$$.fifo
	# 创建管道
	mkfifo $TMPFIFO
	# 创建文件标识符5,这个数字可以为除0,1,2之外的所有未声明过的字符,以读写模式操作管道文件
	# 系统调用exec是以新的进程去替代原来的进程,但进程的PID保持不变,换句话说就是在调用进程内部执行一个可执行文件
	exec 5<>${TMPFIFO}
	rm -rf $TMPFIFO
	
	seq $THREAD >&5
	#for ((i;i<=$THREAD;i++)); do
	#	echo >&5
	#done
	echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	echo "初始化消息队列完成"
}

git_init(){
	# 这两个命令仅仅用于标识提交代码的开发者信息,可以随便设置;仅用于质量追踪到具体某一个人
	git config --global user.name "gaozhiqiang"
	git config --global user.email "1211348968@qq.com"
	# 修正源
	git remote remove origin
	git remote add origin $GITHUB_REPO_ADDR
	if git branch -a | grep 'origin/develop' &> /dev/null; then
		git checkout develop
		git pull origin develop
	else
		git checkout -b develop
		git pull --no-commit origin develop
	fi
	#git clone $GITHUB_REPO_ADDR
	#cd $GITHUB_REPO_NAME
	echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	echo "初始化GITHUB仓库完成"
}

git_commit(){
	#rm -rf $IMAGE_LIST
	local LINES=$(git status -s | wc -l)
	local TODAY=$(date "+%Y%m%d %H:%M:%S")
	if [ $LINES -gt 0 ]; then
		git add -A
		git commit -m "Synchronizing completion at ${TODAY}"
		git push -u origin develop
	fi
	echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	echo "提交GITHUB仓库完成"
	exit
}

add_yum_repo(){
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

add_apt_source(){
	export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"
	echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
	curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
}

sdk_install(){
	echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	OS_VERSION=$(awk -F'"' '/^ID=/{print $(NF-1)}' /etc/os-release | tr a-z A-Z)
	if [ OS_VERSION == 'CENTOS' ]; then
		if [ ! -f /etc/yum.repos.d/google-cloud-sdk.repo ]; then
			add_yum_repo
			sudo yum -y install google-cloud-sdk
			echo "安装软件完成"
		else
			which gcloud &> /dev/null || sudo yum -y install google-cloud-sdk
			echo "安装软件完成"
		fi
	elif [ OS_VERSION == 'UBUNTU' ]; then
		if [ ! -f /etc/apt/sources.list.d/google-cloud-sdk.list ]; then
			add_apt_source
			sudo apt-get -y update && sudo apt-get -y install google-cloud-sdk
			echo "安装软件完成"
		else
			which gcloud &> /dev/null || sudo apt-get -y install google-cloud-sdk
			echo "安装软件完成"
		fi
	else
		# 其实工作在这一层
		add_apt_source
		sudo apt-get -y install google-cloud-sdk &> /dev/null
		echo "安装软件完成"
	fi
}

sdk_auth(){
	echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	# 家目录为/home/travis;当前所在目录为/home/travis/bulid/solomonlinux/gcr.io;同时识别不了~/为家目录
	local AUTH_COUNT=$(gcloud auth list --format="get(ACCOUNT)" | wc -l)
	if [ $AUTH_COUNT -eq 0 ]; then
		#gcloud auth activate-service-account --key-file ~/gcloud.config.json
		#gcloud auth activate-service-account --key-file=./test/gcrio-images-6bdc946edf5b.json
		gcloud auth activate-service-account --key-file=/home/travis/gcrio-images-6bdc946edf5b.json
		[ $? -eq 0 ] && echo "grc.io仓库认证成功" || echo "gcr.io仓库认证失败"
	fi
}

# gcr.io/<namespace>/<image>:<tag> --> gcr.io/<namespace>/<image>/<tag>
image_list_create(){
	echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	# 创建用于保存镜像列表的文件
	IMAGE_LIST=$(mktemp imagelist.XXX)

	# 创建名称空间对应的目录
	#for NS in $GCRIO_NS; do
	NS=$1
	REPOSITORY=gcr.io/${NS}
	[ -d $REPOSITORY ] || mkdir -p $REPOSITORY

	tag_file_check gcr.io
	
	# 创建镜像所对应的目录
	while read IMAGE; do
		# 如果镜像文件夹不存在就创建;如果镜像文件夹下存在latest文件则更名为latest.old文件
		[ -d ${IMAGE} ] || mkdir -p ${IMAGE}
		[ -f ${IMAGE}/latest ] && mv ${IMAGE}/latest{,.old}

		# 创建标签所对应的文件
		while read TAG; do
			# 处理latest镜像
			if [[ $TAG == "latest" ]] && [[ -f ${IMAGE}/latest.old ]]; then
				DIGEST=$(gcloud container images list-tags $IMAGE --format="get(DIGEST)" --filter="tags=latest")
				echo $DIGEST > $IMAGE/latest
				diff ${IMAGE}/latest ${IMAGE}/latest.old &> /dev/null
				if [ $? -ne 0 ]; then
					#docker pull ${IMAGE}:latest
					echo ${IMAGE}:latest >> $IMAGE_LIST
					continue

				fi
			fi
			# 如果文件不存在,则说明镜像不存在,那么就创建文件并拉取镜像;否则就什么都不做
			if [ ! -f ${IMAGE}/${TAG} ]; then
				echo ${IMAGE}:${TAG} > ${IMAGE}/${TAG}
				#docker pull ${IMAGE}:${TAG}
				echo ${IMAGE}:${TAG} >> $IMAGE_LIST
			fi
			#echo ${IMAGE}:${TAG} >> list.txt &
			#echo "文件行数: $(wc -l $IMAGE_LIST)"
		done < <(gcloud container images list-tags $IMAGE --format="get(TAGS)" --filter='tags:*' | sed 's#;#\n#g')

	done < <(gcloud container images list --repository=${REPOSITORY} --format="value(NAME)")
	#done
	echo "${REPOSITORY}仓库准备完成"
}

image_pull(){
	echo "拉取镜像"
	while read LINE; do
		# 如果同步时长超过40min就自动提交
		sync_commit_check

		# 这里对我来说很难处理,可能无法实现并发拉取镜像的效果;原因是在整个循环体里都要做成队列,但是拉取镜像和删除镜像可能存在冲突
		# 也可能不会,再想想应该也没问题;假设磁盘容量在第一次拉取镜像时没有超过70%,那么就不会清理,然后就进入下一个循环,这就实现了并发的效果
		# 还有就是拉取完镜像才能被清理镜像所识别,不会造成边拉去边清理这种冲突
		#for ((i=1;i<=$THREAD;i++)); do
		for I in $(seq $THREAD); do
			read -u5
			{
				docker pull $LINE &> /dev/null && { echo "####################################################################################"; echo "拉取镜像${LINE}成功"; }
				# "echo >&5"错写为"exec >&5"导致放至后台后就没有wait的效果了似的,找到原因了
				echo >&5
			}&
		done
		wait
		
		if [ $(df -h | awk -F " |%" '$NF=="/"{print $(NF-2)}') > $DISK ]; then
			image_push
		fi	
	done < $IMAGE_LIST

	rm -rf $IMAGE_LIST
}

image_push(){
	echo "推送镜像"
	while read REPO TAG;do
		read -u5
		{
		echo "************************************************************************************"
		SRC=${REPO}:${TAG}
		DEST=${DOCKERHUB_REPO_NAME}/$(echo $REPO | tr / ${INTERVAL}):${TAG}
		docker tag $SRC $DEST &> /dev/null && echo "打标完成"
		docker rmi $SRC &> /dev/null && echo "删除源镜像"
		docker push $DEST &> /dev/null && echo "推送镜像${DEST}成功"
		docker rmi $DEST &> /dev/null && echo "删除目标镜像"
		echo >&5
		}&
	done < <(docker images --format {{.Repository}}' '{{.Tag}})
	wait
}

# 检查对应的镜像是否存在
# curl -s https://hub.docker.com/v2/repositories/solomonlinux/nginx/tags/v1-test/ | jq -r .name
# $1: image_name; $2: image_tag_name
dockerhub_tag_exist(){
	curl -s https://hub.docker.com/v2/repositories/${DOCKERHUB_REPO_NAME}/$1/tags/$2/ | jq -r .name
}

# 凡是我们本地有标签但是dockerhub并不存在的镜像标签文件要删除
# $1为gcr.io或者quay.io域
tag_file_check(){
	DOMAIN=$1
	while read PATH FILE; do
		if [ -n $FILE ]; then
			break
		fi
		#IMAGE_NAME=${PATH##*/}
		IMAGE_NAME=$(echo $PATH | tr / $INTERVAL)
		TAGE_NAME=$FILE
		RETURN_VALUE=$(dockerhub_tag_exist $IMAGE_NAME $TAGE_NAME)
		# 如果这个值为空的话就表示文件不存在,那么我们需要跳过本轮循环进入下一轮循环
		# 这个我们不需考虑,因为我们操作的就是文件
		#if [ -n $FILE ]; then
			#continue
			# break
		#fi
		if [ $RETURN_VALUE == 'null' ]; then
			rm -rf ${PATH}/${FILE}
		fi
	done < <( find ${DOMAIN}/ -type f | sed 's#/# #3' )
}

sync_commit_check(){
	if [[ $(( (`date +%s`-$START_TIME)/60 )) -gt 10 ]]; then
		git_commit
	fi
}

generate_changelog(){
	echo
}

main(){
	git_init
	sdk_install
	sdk_auth
	multi_thread_init
	for I in $GCRIO_NS; do
		image_list_create $I
		image_pull
	done
	exec 5>&-
	generate_changelog
	git_commit
}

main
