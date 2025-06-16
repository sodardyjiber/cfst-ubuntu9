#!/bin/bash
set -e  # 遇到错误自动退出脚本

# 1. 关闭v2raya容器
echo "正在停止v2raya容器..."
docker stop v2raya

# 2. 运行CloudflareSpeedTest
echo "正在执行Cloudflare测速..."
cd /mnt/yw-tmp/cfst-ubuntu9  # 进入测速目录
curl -s https://www.cloudflare.com/ips-v4 -o ipv4.txt
./CloudflareST -tp 443 -f ipv4.txt -n 200 -dn 10 -sl 5 -url https://st.bzg.dpdns.org/100m  # 执行测速程序（请确保文件有执行权限）

# 3. 重新启动v2raya容器
echo "正在启动v2raya容器..."
docker start v2raya

# 4.暂停1分钟
sleep 1m

# 4. 上传到GitHub
echo "正在提交更新到GitHub..."
git add .  # 添加所有修改
git commit -m "自动更新测速结果 $(date +'%Y-%m-%d %H:%M:%S')"  # 带时间戳的提交信息
git push -u origin master  # 推送到main分支（按需修改分支名称）



echo "所有操作已完成！"
