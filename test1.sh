#!/usr/bin/env bash

echo "========== serv00 sing-box 自动安装 =========="

WORKDIR=$HOME/singbox
PORT=$(jot -r 1 10000 30000)
UUID=$(uuidgen)

mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit

echo "工作目录: $WORKDIR"

echo "获取最新下载地址..."

URL=$(fetch -qo - https://api.github.com/repos/SagerNet/sing-box/releases/latest \
| grep browser_download_url \
| grep freebsd-amd64.tar.gz \
| cut -d '"' -f4)

if [ -z "$URL" ]; then
    echo "获取下载地址失败"
    exit 1
fi

echo "下载地址:"
echo "$URL"

FILE=$(basename "$URL")

echo "开始下载..."

fetch "$URL"

if [ ! -f "$FILE" ]; then
    echo "下载失败"
    exit 1
fi

echo "解压..."

tar -xzf "$FILE"

DIR=$(ls -d sing-box-* | head -n1)

cp "$DIR/sing-box" .
chmod +x sing-box

rm -rf "$DIR" "$FILE"

echo "生成配置..."

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
      ]
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
echo "========== 安装完成 =========="
echo ""
echo "服务器IP: $IP"
echo "端口: $PORT"
echo "UUID: $UUID"
echo ""
echo "VLESS 链接:"
echo ""
echo "vless://$UUID@$IP:$PORT?encryption=none&type=tcp#serv00-singbox"
echo ""
echo "日志查看:"
echo "tail -f ~/singbox/singbox.log"
echo ""
echo "停止服务:"
echo "pkill sing-box"
