#!/bin/bash
set -e  # 遇到未捕获的错误自动退出

# 【关键修复 1】注册退出陷阱：无论脚本因何种原因退出（哪怕报错或被 kill），都确保重启 v2raya
cleanup() {
    echo "正在检查并恢复 v2raya 容器状态..."
    docker start v2raya >/dev/null 2>&1 || true
}
trap cleanup EXIT

# 1. 关闭 v2raya 容器
echo "正在停止 v2raya 容器..."
docker stop v2raya

# 2. 运行 CloudflareSpeedTest
echo "正在执行 Cloudflare 测速..."
cd /mnt/yw-tmp/cfst-ubuntu9

# 下载 IP 库（增加超时和重试，防止卡死）
curl -s --connect-timeout 10 --retry 3 https://www.cloudflare.com/ips-v4 -o ipv4.txt

# 清理旧的测速结果，防止本次没测出结果时读取到上一次的旧文件
# rm -f result.csv

# 【关键修复 2】
# 1) 使用 timeout 600 限制整个测速最多运行 10 分钟（600秒），防止无合格 IP 时无限测下去
# 2) 尾部追加 < /dev/null 自动跳过“按回车退出”提示
# 3) 追加 || true 防止因超时或无结果返回非0状态码导致脚本直接崩溃
echo "开始测速（最长限时 10 分钟）..."
timeout 600 ./cfst -tp 443 -n 200 -dn 10 -sl 4 -tl 200 -url https://st.bzg.cc.cd/50m < /dev/null || true

# 【关键修复 3】判断是否有测速结果生成，以及文件行数是否大于 1
if [ -f "result.csv" ] && [ $(wc -l < "result.csv") -gt 1 ]; then
    echo "测速完成，正在解析节点物理位置..."
    
    # 如果希望每次覆盖写入新表头，可以取消下面这行的注释：
    # echo "IP,端口,延迟,速度,机场三字码,物理位置" > result_with_location.csv

    tail -n +2 result.csv | head -n 20 | while IFS=, read -r ip port ping loss speed; do
        # 清理可能存在的回车符
        ip=$(echo "$ip" | tr -d '\r')
        
        # 请求 trace 接口获取 colo 节点代码 (加 || true 防止节点不通时触发 set -e 退出)
        colo=$(curl -s -m 2 "http://$ip/cdn-cgi/trace" | grep "colo=" | awk -F= '{print $2}' | tr -d '\r' || true)
        
        case $colo in
            HKG) loc="香港" ;;
            NRT|HND) loc="日本 东京" ;;
            KIX) loc="日本 大阪" ;;
            SIN) loc="新加坡" ;;
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
        
        echo "$ip,$port,$ping,$speed,$colo,$loc" >> result_with_location.csv
    done
else
    echo "警告：本次测速未找到符合条件的合格 IP（result.csv 为空或未生成），跳过位置解析！"
fi

# 3. 重新启动 v2raya 容器
echo "正在启动 v2raya 容器..."
docker start v2raya

# 4. 暂停 1 分钟等待网络代理就绪
echo "等待 1 分钟让代理恢复..."
sleep 1m

# 5. 上传到 GitHub
echo "正在提交更新到 GitHub..."
git add .

# 【关键修复 4】先检查工作区是否有文件变动，有变动才 commit，否则 git commit 会报错中断脚本
if ! git diff --cached --quiet; then
    git commit -m "自动更新测速结果 $(date +'%Y-%m-%d %H:%M:%S')"
    git push -u origin master
    echo "GitHub 推送成功！"
else
    echo "没有新的测速数据需要提交。"
fi

echo "所有操作已完成！"