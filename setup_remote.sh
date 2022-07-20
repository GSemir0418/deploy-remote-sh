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
        #    -v /home/$user/deploys/$version/api:/usr/share/nginx/html:ro \