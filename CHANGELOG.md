# 2019年03月19日
1、修复了指针转动后没有创建列表并拉取镜像,导致指针空转后退出

2、增加镜像首次同步完成之后只执行执行(作废),不能让程序的执行流程缺失一部分

	travis-ci虚拟机启动需要1min左右;
	检查gcr.io/google_containers这个名称空间文件对应镜像(file<->mirror)镜像不存在删除文件需要3min左右
	检查本地文件存在就ok不存在就创建并加入到队列中需要6min左右

3、程序的逻辑没有什么问题,但是却出了问题,可能是bash的用法有问题

4、如果想要镜像能够及时全部更新,最好拆分名称空间,这样的话速度soso的

# 2019年03月20日
1、不再拉取kaggle-notebook镜像(docker pull gcr.io/kubeflow-images-public/kaggle-notebook:v20180713),因为我使用并发为1都会导致travis存活状态监测失败,没办法

2、现在还是将并发调为5个

# 2019年03月21日
1、我发现k8s.gcr.io/镜像与gcr.io/镜像可能还是有一点区别的,所以我还是使用solomonlinux/kubernetes_components来提供kubeadm所需的Pod组件

2、这个脚本对于非常大的镜像无能无力,像kubeflow-images-public这个名称空间的镜像都太大了,而且经常出错,我给delete掉了,以后若是需要再维护好了
