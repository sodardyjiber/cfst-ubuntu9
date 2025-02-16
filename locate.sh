#!/bin/bash

# 检查是否提供了输入文件
if [ -z "$1" ]; then
  echo "用法: $0 <IP 地址列表文件>"
  exit 1
fi

# 输入文件路径
input_file="$1"

# 输出文件路径
output_file="ip_geolocation.csv"

# 写入 CSV 文件头
echo "IP 地址,国家,地区,城市" > "$output_file"

# 读取每个 IP 地址并查询地理位置
while IFS= read -r ip; do
  # 去除可能的空格
  ip=$(echo "$ip" | xargs)
  
  # 跳过空行
  if [ -z "$ip" ]; then
    continue
  fi

  # 使用 ip-api.com 查询地理位置
  response=$(curl -s "http://ip-api.com/json/$ip")
  
  # 解析 JSON 响应
  country=$(echo "$response" | sed -n 's/.*"country":"\([^"]*\)".*/\1/p')
  region=$(echo "$response" | sed -n 's/.*"regionName":"\([^"]*\)".*/\1/p')
  city=$(echo "$response" | sed -n 's/.*"city":"\([^"]*\)".*/\1/p')

  # 如果查询失败，设置为未知
  if [ -z "$country" ]; then
    country="未知"
    region="未知"
    city="未知"
  fi

  # 将结果写入输出文件
  echo "$ip,$country,$region,$city" >> "$output_file"
done < "$input_file"

echo "查询完成，结果已保存到 $output_file"

