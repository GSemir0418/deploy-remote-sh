FROM nginx
# 把dist文件夹下编译好的文件复制到 nginx工作目录
ADD dist/  /usr/share/nginx/html/
# 把Nginx配置文件复制覆盖原有Nginx配置
ADD default.conf /etc/nginx/conf.d/default.conf
WORKDIR /usr/share/nginx/html