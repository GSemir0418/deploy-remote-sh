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