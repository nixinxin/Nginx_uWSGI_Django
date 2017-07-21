#! /bin/sh
# description:一键部署Nginx+uWSGI+Django
# Author: luotianshuaiA

#使用说明
#1、环境:
#一键部署脚本前提您已经保证Django可以通过runserver启动起来并且测试无代码问题
#
#2、目录要求:
#请保证这个脚本，和项目在同一级目录
#    [root@localhost opt]# tree -L 1 project_teacher/
#    project_teacher/
#    |-- deploy_project.sh  #部署脚本
#    `-- teacher  #项目目录
#
#    1 directory, 1 file
#    [root@localhost opt]#
#
#    # 比如脚本在/opt/project_teacher目录下面那么请把项目上传到这个目录下面
#3、您需要的配置项有
#[config1]
#[config2]
#
#4、本脚本使用会自动添加Nginx配置，请确保没有安装Nginx，并且系统为Centos6.5
#

# 这里不需要动,保证脚本目录所在的目录中包含了项目目录即可
MANAGE_DIR=`pwd`
#**************************您的配置区域其他的无需修改**************************
# [config1]项目名称
PROJECT_NAME="teacher"
# [config2]nginx域名或者IP地址和端口，我们用来访问的
SERVER_NAME="192.168.31.123" #也可以是域名
SERVER_PORT=80

#******************************************************************************
# 项目目录
PROJECT_DIR=$MANAGE_DIR/$PROJECT_NAME


# 检查项目目录是否存在
check_project(){
if [ ! -d $PROJECT_DIR ]; then
echo -e "\n\033[33m PROJECT_DIR 没有指定,请指定项目目录\033[0m"
exit 0
elif [ -d $PROJECT_DIR ]; then
echo -e "\033[32m项目目录存在是:$PROJECT_DIR........\033[0m"
fi


}


# 创建脚本管理配置
make_script_init(){
echo -e "\033[32m开始创建script目录........\033[0m"
mkdir script
echo -e "\033[32m开始创建管理文件........\033[0m"
cat > script/manage_$PROJECT_NAME<<EOF
#! /bin/sh
# chkconfig: 345 85 15
# 上面一行注释:哪些Linux级别需要启动manage_teacher(3,4,5)；启动序号(85)；关闭序号(15)。
# description: manage script is the $PROJECT_NAME daemon.
# Author: luotianshuai
# 重载环境变量
export PATH=\$PATH:/usr/local/python3.6/bin
# 指定项目目录
PROJECT_DIR=$PROJECT_DIR
# 指定脚本目录在哪里
SCRIPTS_DIR=$MANAGE_DIR/script
# 描述
DESC="$PROJECT_NAME daemon"
# 名称
NAME=$PROJECT_NAME
# 脚本名称
SCRIPT_FILENAME=manage_$PROJECT_NAME
# 脚本目录名称
SCRIPTNAME=$MANAGE_DIR/script
# PID
PID="uwsgi.pid"

# 启动函数
d_start(){
# 进入到项目目录
cd $MANAGE_DIR/script/
# 判断这个PID是否存在
if [ ! -f "uwsgi.pid" ];then
echo -e "\n\033[34m$NAME项目启动中........\033[0m"
# 如果不存在执行
uwsgi --ini uwsgi.ini
killall nginx
/etc/init.d/nginx start
# 自动收集静态文件
cd $MANAGE_DIR/$PROJECT_NAME&& python3 manage.py collectstatic --noinput
echo -e "\n\033[32m$NAME 项目启动完成........\033[0m"
exit 0
fi
echo -e "\n\033[33m$NAME 项目已启动请勿重复启动\033[0m"
}
# 关闭函数
# 关闭项目
d_stop(){
# 进入脚本目录
cd $MANAGE_DIR/script/
# 判断这个pid文件是否存在
if [ ! -f "uwsgi.pid" ];then
# 这个项目已经关闭了
echo -e "\n\033[33m$NAME 项目已经关闭了请先启动\033[0m"
fi
echo -e "\n\033[34m$NAME 项目关闭中........\033[0m"
echo -e "\nStop $DESC: $NAME"
# 如果没有关闭
uwsgi --stop uwsgi.pid
# 是否停掉Nginx根据实际需要来操作~~！因为Nginx有对静态文件缓存［注意］
killall nginx
/etc/init.d/nginx start
echo -e "\n\033[32m$NAME 项目关闭完成........\033[0m"
}

d_restart(){
d_stop
sleep 1
d_start
}

case "\$1" in
start)
echo -e "\nstarting $DESC: $NAME"
d_start
;;
stop)
echo -e "\nStop $DESC: $NAME"
d_stop
;;
restart)
echo -e "\nRestart $DESC: $NAME"
d_restart
;;
*)
echo "Usage: $SCRIPTNAME {start|stop|restart}" >&2
exit 3
;;
esac
EOF
chmod 755 $MANAGE_DIR/script/manage_$PROJECT_NAME
echo -e "\033[32m开始添加uwsgi.ini配置文件........\033[0m"
cat > script/uwsgi.ini<<EOF
[uwsgi]
# 项目目录
chdir=$PROJECT_DIR
# 启动uwsgi的用户名和用户组
uid=root
gid=root
# 指定项目的application
module=$PROJECT_NAME.wsgi:application
# 指定sock的文件路径
socket=$MANAGE_DIR/script/uwsgi.sock
# 启用主进程
master=true
# 进程个数
workers=5
pidfile=$MANAGE_DIR/script/uwsgi.pid
# 自动移除unix Socket和pid文件当服务停止的时候
vacuum=true
# 序列化接受的内容，如果可能的话
thunder-lock=true
# 启用线程
enable-threads=true
# 设置自中断时间
harakiri=30
# 设置缓冲
post-buffering=4096
# 设置日志目录
daemonize=$MANAGE_DIR/script/uwsgi.log
EOF
echo  "STATIC_ROOT = os.path.join(BASE_DIR, 'static_all')">> $MANAGE_DIR/$PROJECT_NAME/$PROJECT_NAME/settings.py
}

make_nginx_init(){
echo -e "\033[32m初始化Nginx........\033[0m"
cat > /etc/yum.repos.d/nginx.repo<<EOF
[nginx]
name=nginx repo
# 下面这行centos根据你自己的操作系统修改比如：OS/rehel
# 6是你Linux系统的版本，可以通过URL查看路径是否正确
baseurl=http://nginx.org/packages/centos/6/\$basearch/
gpgcheck=0
enabled=1
EOF
yum -y install nginx
echo -e "\033[32m添加Nginx配置文件........\033[0m"

cat > /etc/nginx/conf.d/$PROJECT_NAME.conf<<EOF
    server {
                    listen $SERVER_PORT;
                    server_name $SERVER_NAME ;
                    access_log  /var/log/nginx/access.log  main;
                    charset  utf-8;
                    gzip on;
                    gzip_types text/plain application/x-javascript text/css text/javascript application/x-httpd-php application/json text/json image/jpeg image/gif image/png application/octet-stream;

                    error_page  404           /404.html;
                    error_page   500 502 503 504  /50x.html;
                    # 指定项目路径uwsgi
                    location / {
                        include uwsgi_params;
                        uwsgi_connect_timeout 30;
                        uwsgi_pass unix:$MANAGE_DIR/script/uwsgi.sock;
                    }
                    # 指定静态文件路径
                    location /static/ {
                        alias  $MANAGE_DIR/$PROJECT_NAME/static_all/;
                        index  index.html index.htm;
                    }

    }
EOF
}
add_server(){
echo -e "\033[32m添加管理至服务........\033[0m"
cp $MANAGE_DIR/script/manage_$PROJECT_NAME /etc/init.d/
chkconfig --add /etc/init.d/manage_$PROJECT_NAME
chkconfig /etc/init.d/manage_$PROJECT_NAME on

# 启动服务
echo -e "\033[32m启动服务........\033[0m"
service manage_$PROJECT_NAME start
}


check_project
make_script_init
make_nginx_init
add_server
