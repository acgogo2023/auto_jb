#!/bin/sh

echo "开始安装 Xray-core..."

WORKDIR=$HOME/xray
PORT=10086
UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)

mkdir -p $WORKDIR
cd $WORKDIR

echo "下载 Xray-core..."

fetch -o xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-freebsd-64.zip

echo "解压..."

unzip -o xray.zip

chmod +x xray

echo "生成配置文件..."

cat > config.json <<EOF
{
  "inbounds":[
    {
      "port":$PORT,
      "protocol":"vless",
      "settings":{
        "clients":[
          {
            "id":"$UUID"
          }
        ],
        "decryption":"none"
      },
      "streamSettings":{
        "network":"tcp"
      }
    }
  ],
  "outbounds":[
    {
      "protocol":"freedom"
    }
  ]
}
EOF

echo ""
echo "UUID: $UUID"
echo "端口: $PORT"
echo ""

echo "启动 Xray..."

nohup ./xray run -config config.json > xray.log 2>&1 &

echo "安装完成"
echo "目录: $WORKDIR"
echo "日志: $WORKDIR/xray.log"
