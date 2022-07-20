---
title: "云服务器docker部署"
date: 2022-07-20T13:05:57+08:00
author: "gsemir"
lastmod: 2022-07-20T13:05:57+08:00
draft: false
categories: ["docker"]
tags: ["docker", "nginx", "sh"]
---

# 1 云服务器配置

- 购买阿里云的服务器

- 配置 ssh 密钥对

  - 将宿主机的 ssh 公钥作为密钥对添加至 ECS 实例中

```bash
$ cat ~/.ssh/id_rsa.pub
```

- 登录至云服务器，第一次使用 ssh-copy-id 命令访问，输入密码登录，以后就自动使用密钥对登录了

```bash
$ ssh-copy-id root@47.114.89.76
# 输入密码登录后ctrl d注销登录
$ ssh root@47.114.89.76
```

- 添加安全策略

  - 开启测试端口，即供外网访问的端口，如 3000、3001、5000、8000、8080，
  - 若开启 80 端口（HTTP 默认端口）以及 443 端口（HTTPS 默认端口），则需提前备案

- 云服务器安装 docker，复制粘贴下面的命令即可

> [Install Docker Engine on Ubuntu | Docker Documentation](https://docs.docker.com/engine/install/ubuntu/)

```shell
# root用户不需要sudo
$ sudo apt-get update
$ sudo apt-get install \
    	ca-certificates \
    	curl \
   		gnupg \
    	lsb-release
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
$ echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
$ sudo apt-get update
$ sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
# 看看是否安装成功
$ docker --version
```

- 推荐只在 root 用户里安装 docker

- 创建新用户，并将其加入 docker 命令组

```shell
$ adduser gsq
# 输入两次密码，然后回车*n
# 将新用户加入docker命令组
$ usermod -a -G docker gsq
# 把root的ssh key及其所有权复制转移到gsq用户下
# 创建目录
$ mkdir /home/gsq/.ssh
# 复制文件
$ cp ~/.ssh/authorized_keys /home/gsq/.ssh
# 转移.ssh文件夹内文件的权限
$ cd /home/gsq/
# chown:change own
# -R:递归地
# 用户组:用户
$ chown -R gsq:gsq .ssh
# 退出，再用新用户登录
$ ssh gsq@47.114.89.76
```

- 注意

  - 为每个应用创建一个独立用户，并加入 docker 用户组

  - 切忌用 root 管理所有应用

# 2 云服务器部署

## 2.1 Docker 开发环境访问云服务器

1. 开发环境容器生成自己的 ssh key

```bash
$ ssh-keygen -t rsa -C "your_email@qq.com"
```

2. 开发环境的 ssh 上传至云服务器的 root 用户(也可以手动复制过去)

```bash
$ ssh-copy-id gsq@your_ip
```

3. 以 root 用户登录云服务器，将 root 的`authorized_keys`赋给 gsq 用户

```bash
$ ssh root@your_ip
# 检查authorized_keys，应该是多了一个
$ cat ~/.ssh/authorized_keys
# 拷贝root的authorized_keys至gsq用户
$ cp ~/.ssh/authorized_keys /home/gsq/.ssh
# 权限也移交给gsq用户
$ cd /home/gsq
$ chown -R gsq:gsq .ssh
# exit 然后直接使用ssh登录gsq用户即可
$ ssh mangosteen@your_ip
```

## 2.2 部署脚本

> `deploy_remote.sh`

```sh
user=gsq
ip=114.55.42.152
current_dir=$(dirname $0)
time=$(date +'%Y%m%d-%H%M%S')
deploy_dir=/home/$user/deploys/$time
dist=$current_dir/dist/
function title {
  echo
  echo "###############################################################################"
  echo "## $1"
  echo "###############################################################################"
  echo
}
title '创建远程目录'
ssh $user@$ip "mkdir -p $deploy_dir"
title '上传dist'
scp -r $dist $user@$ip:$deploy_dir
title '上传 Dockerfile'
scp $current_dir/Dockerfile $user@$ip:$deploy_dir/
title '上传 default.conf'
scp $current_dir/default.conf $user@$ip:$deploy_dir/
title '上传 setup 脚本'
scp $current_dir/setup_remote.sh $user@$ip:$deploy_dir/
title '执行远程脚本'
ssh $user@$ip "export version=$time; /bin/bash $deploy_dir/setup_remote.sh"
```

## 2.3 远程服务器构建容器脚本

> `setup_remote.sh`

```sh
user=gsq
root=/home/$user/deploys/$version
nginx_container_name=nginx-test-1
function title {
  echo
  echo "###############################################################################"
  echo "## $1"
  echo "###############################################################################"
  echo
}

title 'app: docker build'
docker build $root -t nginx-test:$version

if [ "$(docker ps -aq -f name=^nginx-test-1$)" ]; then
  title 'app: docker rm'
  docker rm -f $nginx_container_name
fi
title 'doc: docker run'
docker run -d -p 8000:80 \
           --network=network1 \
           --name=$nginx_container_name \
           nginx-test:$version

title '全部执行完毕'
```

- 为以上两个文件添加可执行权限

`chmod +x bin/pack_for_remote bin/setup_remote`

## 2.4 Dockerfile

> Dockerfile

```dockerfile
FROM nginx
# 把dist文件夹下编译好的文件复制到 nginx工作目录
ADD dist/  /usr/share/nginx/html/
# 把Nginx配置文件复制覆盖原有Nginx配置
ADD default.conf /etc/nginx/conf.d/default.conf
WORKDIR /usr/share/nginx/html
```

## 2.5 nginx 配置

> default.conf

```nginx
server {
  # 监听服务器80端口
  listen       80 default_server;
  listen       [::]:80 default_server;
  # 监听地址
  server_name  _;
  # 所有web项目的根目录
  root         /usr/share/nginx/html;

  # 指定在当前文件中包含另一个文件的指令
  include /etc/nginx/default.d/*.conf;

  # 配置路由访问信息
  # / 表示匹配根目录
  location / {
    try_files $uri $uri/ @router;
    # 在不指定访问具体资源时，默认展示的文件列表
    index  index.html index.htm;
  }

  # 配置router 这是为了vue的？
  location @router {
    # 地址重定向
    # 访问全部的
    rewrite ^.*$ /index.html last;
  }

  # 请求url过滤 正则匹配 ~为区分大写 ~*为不区分大小写
  # 解决nginx无法加载.woff .eot .ttf的方法
  location ~* \.(eot|ttf|woff)$ {
    # 允许cros跨域访问
    add_header Access-Control-Allow-Origin '*';
    add_header Access-Control-Allow-Headers Authorization;
  }
}
```
