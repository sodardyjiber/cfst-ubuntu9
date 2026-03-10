#!/bin/bash
set -e  # 遇到错误自动退出脚本

# 1. 关闭v2raya容器
echo "正在停止v2raya容器..."
docker stop v2raya

# 2. 运行CloudflareSpeedTest
echo "正在执行Cloudflare测速..."
cd /mnt/yw-tmp/cfst-ubuntu9  # 进入测速目录
curl -s https://www.cloudflare.com/ips-v4 -o ipv4.txt
./CloudflareST -tp 443 -f ipv4.txt -n 200 -dn 10 -sl 4 -url https://st.bzg.cc.cd/50m  # 执行测速程序（请确保文件有执行权限）

tail -n +2 result.csv | head -n 20 | while IFS=, read -r ip port ping loss speed; do
    # 请求 trace 接口获取 colo 节点代码 (设置 2 秒超时防止卡死)
    colo=$(curl -s -m 2 http://$ip/cdn-cgi/trace | grep colo= | awk -F= '{print $2}')
    
    # 匹配三字代码到具体城市 (这里列出了亚太和美西常见的节点，可自行补充)
    case $colo in
        HKG) loc="香港" ;;
        NRT|HND) loc="日本 东京" ;;
        KIX) loc="日本 大阪" ;;
        SGP) loc="新加坡" ;;
        TPE) loc="台湾 台北" ;;
        ICN) loc="韩国 首尔" ;;
        SJC) loc="美国 圣何塞" ;;
        LAX) loc="美国 洛杉矶" ;;
        SFO) loc="美国 旧金山" ;;
        SEA) loc="美国 西雅图" ;;
        FRA) loc="德国 法兰克福" ;;
        LHR) loc="英国 伦敦" ;;
        "")  loc="超时/阻断" ; colo="N/A" ;;
        *)   loc="其他节点" ;;
    esac
    
    # 将包含位置的信息写入新文件
    echo "$ip,$port,$ping,$speed,$colo,$loc" >> result_with_location.csv
done

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
