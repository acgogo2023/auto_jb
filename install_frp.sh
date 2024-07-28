#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 没有颜色

# 定义下载地址
INTERNATIONAL_DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/v"
DOMESTIC_DOWNLOAD_URL="https://gitee.com/git220/frp/releases/download/v"

# 提示用户选择下载地址
echo -e "${YELLOW}请选择下载地址：${NC}"
echo "1. 国内 (Gitee)"
echo "2. 国际 (GitHub)"
while true; do
  read -p "请输入 1 或 2: " DOWNLOAD_CHOICE
  if [ "$DOWNLOAD_CHOICE" = "1" ] || [ "$DOWNLOAD_CHOICE" = "2" ]; then
    break
  else
    echo -e "${RED}无效的输入，请输入 1 或 2。${NC}"
  fi
done

# 设置下载地址
if [ "$DOWNLOAD_CHOICE" = "1" ]; then
  DOWNLOAD_BASE_URL="${DOMESTIC_DOWNLOAD_URL}"
else
  DOWNLOAD_BASE_URL="${INTERNATIONAL_DOWNLOAD_URL}"
fi

# 检查最新版本
LATEST_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
DEFAULT_VERSION="0.59.0"

# 提示用户选择版本
echo -e "${YELLOW}你想下载并使用最新版本的 FRP 吗？(默认是 $DEFAULT_VERSION)${NC}"
while true; do
  read -p "请输入 yes 或 no: " USE_LATEST
  if [ "$USE_LATEST" = "yes" ] || [ "$USE_LATEST" = "no" ]; then
    break
  else
    echo -e "${RED}无效的输入，请输入 yes 或 no。${NC}"
  fi
done

if [ "$USE_LATEST" = "yes" ]; then
  FRP_VERSION=$LATEST_VERSION
else
  FRP_VERSION=$DEFAULT_VERSION
fi

# 定义文件名
FRP_TAR="frp_${FRP_VERSION}_linux_amd64.tar.gz"
FRP_DIR="frp_${FRP_VERSION}_linux_amd64"

# 完整下载地址
DOWNLOAD_URL="${DOWNLOAD_BASE_URL}${FRP_VERSION}/${FRP_TAR}"

# 检查是否已下载FRP文件
if [ ! -f "$FRP_TAR" ]; then
  echo -e "${GREEN}正在下载 FRP ${FRP_VERSION}...${NC}"
  curl -LO $DOWNLOAD_URL
else
  echo -e "${GREEN}FRP 文件已存在，跳过下载步骤。${NC}"
fi

# 检查是否已解压FRP文件
if [ ! -d "$FRP_DIR" ]; then
  echo -e "${GREEN}正在解压 FRP...${NC}"
  tar -xzvf $FRP_TAR
else
  echo -e "${GREEN}FRP 已经解压，跳过解压步骤。${NC}"
fi

# 进入FRP目录
cd $FRP_DIR

# 提示用户选择配置和启动FRPC或FRPS
while true; do
  read -p "你想配置和启动 FRPC 还是 FRPS? (输入 'FRPC' 或 'FRPS'): " CHOICE
  if [[ "$CHOICE" =~ ^(FRPC|frpc|FRPS|frps)$ ]]; then
    CHOICE=$(echo "$CHOICE" | tr '[:lower:]' '[:upper:]') # 转换为大写
    break
  else
    echo -e "${RED}无效的选择，请输入 'FRPC' 或 'FRPS'。${NC}"
  fi
done

if [ "$CHOICE" = "FRPC" ]; then
  # 提示用户输入FRPC配置
  read -p "请输入服务器地址 (server_addr) [服务端的IP]: " SERVER_ADDR
  read -p "请输入服务器端口 (server_port) [默认7000]: " SERVER_PORT

  # 如果用户没有输入server_port，使用默认值7000
  if [ -z "$SERVER_PORT" ]; then
    SERVER_PORT=7000
  fi

  # 提示用户输入FRPC的local_port和remote_port
  read -p "请输入 FRPC 本地端口 (local_port): " LOCAL_PORT
  read -p "请输入 FRPC 远程端口 (remote_port): " REMOTE_PORT

  # 提示用户输入 [http_proxy] 名称
  read -p "请输入 [http_proxy] 名称: " HTTP_PROXY_NAME

  # 更新 frpc.toml 文件
  cat > frpc.toml <<EOL
[common]
server_addr = $SERVER_ADDR
server_port = $SERVER_PORT
log_file = "frpc.log"
log_level = "info"
log_max_days = 1

[$HTTP_PROXY_NAME]
type = tcp
plugin = http_proxy
local_ip = 127.0.0.1
local_port = $LOCAL_PORT
remote_port = $REMOTE_PORT
EOL

  # 提示用户配置完成
  echo -e "${GREEN}FRPC 配置完成。${NC}"

  # 提示用户是否启动FRPC
  while true; do
    read -p "你要现在启动 FRPC 吗? (yes/no): " RUN_FRPC
    if [ "$RUN_FRPC" = "yes" ] || [ "$RUN_FRPC" = "no" ]; then
      break
    else
      echo -e "${RED}无效的输入，请输入 yes 或 no。${NC}"
    fi
  done

  if [ "$RUN_FRPC" = "yes" ]; then
    while true; do
      read -p "你要在后台运行 FRPC 吗? (yes/no): " BACKGROUND_FRPC
      if [ "$BACKGROUND_FRPC" = "yes" ] || [ "$BACKGROUND_FRPC" = "no" ]; then
        break
      else
        echo -e "${RED}无效的输入，请输入 yes 或 no。${NC}"
      fi
    done
    
    if [ "$BACKGROUND_FRPC" = "yes" ]; then
      nohup ./frpc -c ./frpc.toml &
      echo -e "${GREEN}FRPC 已在后台启动。${NC}"
    else
      ./frpc -c ./frpc.toml
    fi
  else
    echo -e "${YELLOW}你可以稍后使用以下命令启动 FRPC:${NC}"
    echo "./frpc -c ./frpc.toml"
    echo -e "${YELLOW}你可以使用以下命令在后台运行 FRPC:${NC}"
    echo "nohup ./frpc -c ./frpc.toml &"
  fi

elif [ "$CHOICE" = "FRPS" ] || [ "$CHOICE" = "frps" ]; then
  # 提示用户输入FRPS配置
  read -p "请输入 FRPS 监听端口 (bind_port) [默认7000]: " FRPS_PORT

  # 如果用户没有输入FRPS端口，使用默认值7000
  if [ -z "$FRPS_PORT" ]; then
    FRPS_PORT=7000
  fi

  # 提示用户输入FRPS的账户和密码
  read -p "请输入 FRPS 账户 (auth_user): " AUTH_USER
  read -p "请输入 FRPS 密码 (auth_pass): " AUTH_PASS
  echo # 换行

  # 更新 frps.toml 文件
  cat > frps.toml <<EOL
[common]
bind_addr = 0.0.0.0
bind_port = $FRPS_PORT
log_file = "frps.log"
log_level = "info"
log_max_days = 1

[auth]
auth_user = $AUTH_USER
auth_pass = $AUTH_PASS

dashboard_port = 7500
EOL

  # 提示用户配置完成
  echo -e "${GREEN}FRPS 配置完成。${NC}"

  # 提示用户是否启动FRPS
  while true; do
    read -p "你要现在启动 FRPS 吗? (yes/no): " RUN_FRPS
    if [ "$RUN_FRPS" = "yes" ] || [ "$RUN_FRPS" = "no" ]; then
      break
    else
      echo -e "${RED}无效的输入，请输入 yes 或 no。${NC}"
    fi
  done

  if [ "$RUN_FRPS" = "yes" ]; then
    while true; do
      read -p "你要在后台运行 FRPS 吗? (yes/no): " BACKGROUND_FRPS
      if [ "$BACKGROUND_FRPS" = "yes" ] || [ "$BACKGROUND_FRPS" = "no" ]; then
        break
      else
        echo -e "${RED}无效的输入，请输入 yes 或 no。${NC}"
      fi
    done

    if [ "$BACKGROUND_FRPS" = "yes" ]; then
      nohup ./frps -c ./frps.toml &
      echo -e "${GREEN}FRPS 已在后台启动。${NC}"
    else
      ./frps -c ./frps.toml
    fi
  else
    echo -e "${YELLOW}你可以稍后使用以下命令启动 FRPS:${NC}"
    echo "./frps -c ./frps.toml"
    echo -e "${YELLOW}你可以使用以下命令在后台运行 FRPS:${NC}"
    echo "nohup ./frps -c ./frps.toml &"
  fi

else
  echo -e "${RED}无效的选择，请重新运行脚本并输入 'FRPC' 或 'FRPS'。${NC}"
fi
