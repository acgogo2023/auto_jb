#!/usr/bin/env bash

echo "====== serv00 FreeBSD sing-box 一键安装 ======"

WORKDIR=$HOME/singbox
PORT=$((RANDOM%20000+10000))
UUID=$(uuidgen)

mkdir -p $WORKDIR
cd $WORKDIR

echo "下载 sing-box..."

fetch -o sing-box.tar.gz https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-freebsd-amd64.tar.gz

echo "解压..."

tar -xzf sing-box.tar.gz
DIR=$(ls | grep sing-box)

mv $DIR/sing-box .
chmod +x sing-box
rm -rf $DIR sing-box.tar.gz

echo "生成配置文件..."

cat > config.json <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "vless",
      "listen": "0.0.0.0",
      "listen_port": $PORT,
      "users": [
        {
          "uuid": "$UUID"
        }
      ],
      "transport": {
        "type": "tcp"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct"
    }
  ]
}
EOF

echo "启动 sing-box..."

nohup ./sing-box run -c config.json > singbox.log 2>&1 &

sleep 2

IP=$(fetch -qo - https://api.ipify.org)

echo ""
echo "====== 安装完成 ======"
echo ""
echo "服务器IP: $IP"
echo "端口: $PORT"
echo "UUID: $UUID"
echo ""

echo "VLESS链接："

echo "vless://$UUID@$IP:$PORT?encryption=none&type=tcp#serv00-singbox"

echo ""
echo "查看日志:"
echo "tail -f ~/singbox/singbox.log"
echo ""
echo "停止服务:"
echo "pkill sing-box"
