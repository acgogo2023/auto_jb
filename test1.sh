#!/usr/bin/env bash

echo "========== serv00 sing-box 自动安装 =========="

WORKDIR=$HOME/singbox
PORT=$(jot -r 1 10000 30000)
UUID=$(uuidgen)

mkdir -p $WORKDIR
cd $WORKDIR || exit

echo "创建工作目录: $WORKDIR"

echo "获取最新 sing-box 版本..."

VERSION=$(fetch -qo - https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep tag_name | cut -d '"' -f4)

echo "最新版本: $VERSION"

FILE="sing-box-${VERSION#v}-freebsd-amd64.tar.gz"

echo "下载 sing-box..."

fetch https://github.com/SagerNet/sing-box/releases/download/$VERSION/$FILE

if [ ! -f "$FILE" ]; then
    echo "下载失败"
    exit 1
fi

echo "解压文件..."

tar -xzf $FILE

DIR=$(ls -d sing-box-*/ | head -n1)

cp $DIR/sing-box .
chmod +x sing-box

rm -rf $DIR $FILE

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
