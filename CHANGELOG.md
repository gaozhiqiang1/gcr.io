# 2019年03月19日
1、修复了指针转动后没有创建列表并拉取镜像,导致指针空转后退出\n
2、增加镜像首次同步完成之后只执行执行(作废),不能让程序的执行流程缺失一部分\n
	travis-ci虚拟机启动需要1min左右;\n
	检查gcr.io/google_containers这个名称空间文件对应镜像(file<->mirror)镜像不存在删除文件需要3min左右\n
	检查本地文件存在就ok不存在就创建并加入到队列中需要6min左右\n
3、程序的逻辑没有什么问题,但是却出了问题,可能是bash的用法有问题\n
4、如果想要镜像能够及时全部更新,最好拆分名称空间,这样的话速度soso的\n

# 2019年03月20日
1、不再拉取kaggle-notebook镜像(docker pull gcr.io/kubeflow-images-public/kaggle-notebook:v20180713),因为我使用并发为1都会导致travis存活状态监测失败,没办法
2、现在还是将并发调为5个
