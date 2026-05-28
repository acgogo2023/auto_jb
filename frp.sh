#!/bin/bash

# ============ FRP 管理脚本 ============
# 版本: 2.3.4
# 功能: 下载、配置、管理 FRP 服务（支持多客户端配置，状态显示优化）
# ====================================

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ============ 全局变量定义 ============
SCRIPT_VERSION="2.3.4"
DEFAULT_VERSION="0.69.0"
CURRENT_DIR=$(pwd)
FRP_BASE_DIR="/opt/frp"
VERSION_FILE="$FRP_BASE_DIR/.frp_version"
LOCK_FILE="/tmp/frp_install.lock"

# 创建基础目录
mkdir -p "$FRP_BASE_DIR"

# ============ 检测系统架构 ============
detect_architecture() {
    local arch
    arch=$(uname -m)
    
    case $arch in
        x86_64) echo "linux_amd64" ;;
        aarch64|arm64) echo "linux_arm64" ;;
        armv7l|armv6l) echo "linux_arm" ;;
        i386|i686) echo "linux_386" ;;
        *) echo "unknown" ;;
    esac
}

ARCH=$(detect_architecture)
echo -e "${GREEN}检测到系统架构: $ARCH${NC}"

if [ "$ARCH" = "unknown" ]; then
    echo -e "${RED}不支持的系统架构，脚本退出${NC}"
    exit 1
fi

# ============ 初始化环境 ============
init_environment() {
    if [ -f "$VERSION_FILE" ]; then
        INSTALLED_VERSION=$(cat "$VERSION_FILE")
        echo -e "${GREEN}检测到已安装FRP版本: $INSTALLED_VERSION${NC}"
    else
        INSTALLED_VERSION=""
        echo -e "${YELLOW}未检测到已安装FRP版本${NC}"
    fi
}

# ============ 辅助函数：统一处理Y/n输入 ============
confirm_yes_no() {
    local prompt=$1
    local default=$2
    local result
    
    while true; do
        if [ "$default" = "Y" ]; then
            read -p "$prompt [Y/n]: " result
            result=${result:-Y}
        elif [ "$default" = "N" ]; then
            read -p "$prompt [y/N]: " result
            result=${result:-N}
        else
            read -p "$prompt [y/n]: " result
        fi
        
        # 转换为小写进行比较
        case ${result,,} in
            y) return 0 ;;
            n) return 1 ;;
            *) echo -e "${RED}请输入 y 或 n${NC}" ;;
        esac
    done
}

# ============ 下载FRP ============
download_frp_once() {
    local target_version=$1
    local FRP_DIR_NAME="frp_${target_version}_${ARCH}"
    local FRP_TAR="${FRP_DIR_NAME}.tar.gz"
    local FRP_INSTALL_PATH="$FRP_BASE_DIR/$FRP_DIR_NAME"
    
    if [ -d "$FRP_INSTALL_PATH" ] && [ -f "$FRP_INSTALL_PATH/frpc" ]; then
        echo -e "${GREEN}FRP $target_version 已存在于 $FRP_INSTALL_PATH${NC}"
        return 0
    fi
    
    if [ -f "$LOCK_FILE" ]; then
        echo -e "${YELLOW}另一个下载任务正在进行中，请稍后...${NC}"
        sleep 2
        return 1
    fi
    
    touch "$LOCK_FILE"
    
    INTERNATIONAL_DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/v"
    DOMESTIC_DOWNLOAD_URL="https://gitee.com/git220/frp/releases/download/v"
    
    echo -e "\n${YELLOW}请选择下载地址：${NC}"
    echo "1. 国内 (Gitee)"
    echo "2. 国际 (GitHub)"
    
    while true; do
        read -p "请输入 1 或 2 (直接回车默认选择1): " DOWNLOAD_CHOICE
        if [ -z "$DOWNLOAD_CHOICE" ]; then
            DOWNLOAD_CHOICE="1"
            break
        fi
        if [ "$DOWNLOAD_CHOICE" = "1" ] || [ "$DOWNLOAD_CHOICE" = "2" ]; then
            break
        else
            echo -e "${RED}无效的输入，请输入 1 或 2。${NC}"
        fi
    done
    
    if [ "$DOWNLOAD_CHOICE" = "1" ]; then
        DOWNLOAD_BASE_URL="${DOMESTIC_DOWNLOAD_URL}"
        SOURCE_NAME="Gitee"
    else
        DOWNLOAD_BASE_URL="${INTERNATIONAL_DOWNLOAD_URL}"
        SOURCE_NAME="GitHub"
    fi
    
    local DOWNLOAD_URL="${DOWNLOAD_BASE_URL}${target_version}/${FRP_TAR}"
    
    echo -e "${GREEN}下载源: $SOURCE_NAME${NC}"
    echo -e "${GREEN}版本: $target_version${NC}"
    
    cd "$FRP_BASE_DIR" || exit 1
    
    if [ ! -f "$FRP_TAR" ]; then
        echo -e "${GREEN}正在下载 FRP ${target_version}...${NC}"
        if curl -L --progress-bar -o "$FRP_TAR" "$DOWNLOAD_URL"; then
            echo -e "${GREEN}下载成功！${NC}"
        else
            echo -e "${RED}下载失败，请检查网络连接${NC}"
            rm -f "$LOCK_FILE"
            cd "$CURRENT_DIR" || exit 1
            return 1
        fi
    else
        echo -e "${GREEN}FRP 安装包已存在，跳过下载。${NC}"
    fi
    
    if [ ! -d "$FRP_DIR_NAME" ]; then
        echo -e "${GREEN}正在解压 FRP...${NC}"
        tar -xzvf "$FRP_TAR"
        if [ $? -ne 0 ]; then
            echo -e "${RED}解压失败，文件可能损坏${NC}"
            rm -f "$FRP_TAR"
            rm -f "$LOCK_FILE"
            cd "$CURRENT_DIR" || exit 1
            return 1
        fi
    else
        echo -e "${GREEN}FRP 已解压，跳过解压步骤。${NC}"
    fi
    
    rm -f "$LOCK_FILE"
    cd "$CURRENT_DIR" || exit 1
    
    echo -e "${GREEN}FRP $target_version 下载完成！${NC}"
    return 0
}

# ============ 版本升级（保留配置） ============
upgrade_frp() {
    local new_version=$1
    local old_version=$INSTALLED_VERSION
    local old_dir="$FRP_BASE_DIR/frp_${old_version}_${ARCH}"
    local new_dir="$FRP_BASE_DIR/frp_${new_version}_${ARCH}"
    
    echo -e "\n${YELLOW}════════════════ FRP 版本升级 ════════════════${NC}"
    echo -e "当前版本: ${GREEN}$old_version${NC}"
    echo -e "目标版本: ${YELLOW}$new_version${NC}"
    
    echo -e "\n${GREEN}步骤1: 下载新版本 FRP $new_version${NC}"
    if ! download_frp_once "$new_version"; then
        echo -e "${RED}下载失败，升级中止${NC}"
        return 1
    fi
    
    echo -e "\n${GREEN}步骤2: 迁移配置文件${NC}"
    
    local has_config=0
    local backup_dir="$FRP_BASE_DIR/backups"
    mkdir -p "$backup_dir"
    local backup_time=$(date +%Y%m%d_%H%M%S)
    
    if [ -d "$old_dir" ]; then
        for cfg in "$old_dir"/frpc*.toml; do
            if [ -f "$cfg" ]; then
                local cfg_name=$(basename "$cfg")
                cp "$cfg" "$backup_dir/${cfg_name}.${old_version}.${backup_time}"
                cp "$cfg" "$new_dir/"
                echo -e "${GREEN}  ✅ 已迁移: $cfg_name${NC}"
                has_config=1
            fi
        done
        
        if [ -f "$old_dir/frps.toml" ]; then
            cp "$old_dir/frps.toml" "$backup_dir/frps.toml.${old_version}.${backup_time}"
            cp "$old_dir/frps.toml" "$new_dir/frps.toml"
            echo -e "${GREEN}  ✅ 已迁移: frps.toml${NC}"
            has_config=1
        fi
        
        echo -e "${GREEN}  ✅ 配置已备份到: $backup_dir${NC}"
    fi
    
    if [ $has_config -eq 0 ]; then
        echo -e "${YELLOW}  ⚠ 未找到旧配置文件，跳过迁移${NC}"
    fi
    
    echo -e "\n${GREEN}步骤3: 更新系统服务${NC}"
    local services_updated=0
    
    local service_file="/etc/systemd/system/frps.service"
    if [ -f "$service_file" ]; then
        if grep -q "$old_dir" "$service_file"; then
            cp "$service_file" "${service_file}.backup.${backup_time}"
            sed -i "s|${old_dir}|${new_dir}|g" "$service_file"
            echo -e "${GREEN}  ✅ frps 服务配置已更新${NC}"
            services_updated=1
        fi
    fi
    
    for service_file in /etc/systemd/system/frpc*.service; do
        if [ -f "$service_file" ]; then
            if grep -q "$old_dir" "$service_file"; then
                cp "$service_file" "${service_file}.backup.${backup_time}"
                sed -i "s|${old_dir}|${new_dir}|g" "$service_file"
                echo -e "${GREEN}  ✅ $(basename "$service_file") 服务配置已更新${NC}"
                services_updated=1
            fi
        fi
    done
    
    if [ $services_updated -eq 1 ]; then
        systemctl daemon-reload
        echo -e "${GREEN}  ✅ systemd 配置已重载${NC}"
    fi
    
    echo "$new_version" > "$VERSION_FILE"
    INSTALLED_VERSION="$new_version"
    
    echo -e "\n${GREEN}步骤4: 重启服务${NC}"
    local need_restart=0
    
    for service in frps frpc frpc2 frpc3; do
        if systemctl is-active --quiet $service 2>/dev/null; then
            need_restart=1
            break
        fi
    done
    
    if [ $need_restart -eq 1 ]; then
        if confirm_yes_no "服务已更新，是否立即重启 FRP 服务?" "N"; then
            for service in frps frpc frpc2 frpc3; do
                if systemctl is-active --quiet $service 2>/dev/null; then
                    echo -e "${YELLOW}  重启 $service...${NC}"
                    systemctl restart $service
                    echo -e "${GREEN}  ✅ $service 已重启${NC}"
                fi
            done
        fi
    fi
    
    echo -e "\n${GREEN}步骤5: 清理旧版本${NC}"
    echo -e "是否保留旧版本 FRP $old_version？"
    echo "1. 保留（可随时回滚）"
    echo "2. 删除（节省空间）"
    
    while true; do
        read -p "请选择 [1-2] (默认1): " KEEP_OLD
        if [ -z "$KEEP_OLD" ]; then
            KEEP_OLD="1"
            break
        fi
        if [[ "$KEEP_OLD" =~ ^[1-2]$ ]]; then
            break
        fi
    done
    
    if [ "$KEEP_OLD" = "2" ]; then
        echo -e "${YELLOW}  正在删除旧版本: $old_dir${NC}"
        rm -rf "$old_dir"
        rm -f "$FRP_BASE_DIR/frp_${old_version}_${ARCH}.tar.gz"
        echo -e "${GREEN}  ✅ 旧版本已删除${NC}"
    else
        echo -e "${GREEN}  ✅ 已保留旧版本: $old_dir${NC}"
    fi
    
    echo -e "\n${GREEN}════════════════ 升级完成 ════════════════${NC}"
    echo -e "当前版本: ${GREEN}$new_version${NC}"
}

# ============ 版本回滚 ============
rollback_frp() {
    echo -e "\n${YELLOW}════════════════ FRP 版本回滚 ════════════════${NC}"
    
    local versions=()
    local version_dirs=()
    
    for dir in "$FRP_BASE_DIR"/frp_*_"$ARCH"; do
        if [ -d "$dir" ]; then
            local ver=$(basename "$dir" | sed "s/frp_\(.*\)_${ARCH}/\1/")
            versions+=("$ver")
            version_dirs+=("$dir")
        fi
    done
    
    if [ ${#versions[@]} -le 1 ]; then
        echo -e "${RED}错误: 没有其他版本可供回滚${NC}"
        return 1
    fi
    
    echo -e "${GREEN}可用的FRP版本:${NC}"
    for i in "${!versions[@]}"; do
        if [ "${versions[$i]}" = "$INSTALLED_VERSION" ]; then
            echo -e "  $((i+1)). ${versions[$i]} ${GREEN}(当前版本)${NC}"
        else
            echo -e "  $((i+1)). ${versions[$i]}"
        fi
    done
    
    read -p "请选择要回滚到的版本: " ROLLBACK_CHOICE
    
    if [[ "$ROLLBACK_CHOICE" =~ ^[0-9]+$ ]] && [ "$ROLLBACK_CHOICE" -ge 1 ] && [ "$ROLLBACK_CHOICE" -le ${#versions[@]} ]; then
        local target_version="${versions[$((ROLLBACK_CHOICE-1))]}"
        
        if [ "$target_version" = "$INSTALLED_VERSION" ]; then
            echo -e "${YELLOW}当前已是此版本${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}正在回滚到版本: $target_version${NC}"
        
        local old_dir="$FRP_BASE_DIR/frp_${INSTALLED_VERSION}_${ARCH}"
        local new_dir="$FRP_BASE_DIR/frp_${target_version}_${ARCH}"
        
        local service_file="/etc/systemd/system/frps.service"
        if [ -f "$service_file" ]; then
            sed -i "s|${old_dir}|${new_dir}|g" "$service_file"
        fi
        
        for service_file in /etc/systemd/system/frpc*.service; do
            if [ -f "$service_file" ]; then
                sed -i "s|${old_dir}|${new_dir}|g" "$service_file"
            fi
        done
        
        systemctl daemon-reload
        
        echo "$target_version" > "$VERSION_FILE"
        INSTALLED_VERSION="$target_version"
        
        echo -e "${GREEN}回滚完成，当前版本: $target_version${NC}"
        
        if confirm_yes_no "是否重启服务?" "N"; then
            for service in frps frpc frpc2 frpc3; do
                if systemctl is-active --quiet $service 2>/dev/null; then
                    systemctl restart $service
                    echo -e "${GREEN}$service 已重启${NC}"
                fi
            done
        fi
    fi
}

# ============ 进入FRP工作目录 ============
enter_frp_workdir() {
    local version_to_use="$INSTALLED_VERSION"
    
    if [ -z "$version_to_use" ]; then
        echo -e "${YELLOW}未检测到已安装版本，请先下载FRP${NC}"
        return 1
    fi
    
    local work_dir="$FRP_BASE_DIR/frp_${version_to_use}_${ARCH}"
    
    if [ ! -d "$work_dir" ]; then
        echo -e "${RED}错误：FRP目录不存在 $work_dir${NC}"
        return 1
    fi
    
    cd "$work_dir" || {
        echo -e "${RED}进入目录失败${NC}"
        return 1
    }
    
    return 0
}

# ============ 快速状态查看（优化版，集成FRPS配置信息但精简显示） ============
quick_status() {
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━ FRP 状态 ━━━━━━━━━━━━━━━━${NC}"
    
    local has_frp=0
    local service_pids=()
    
    # ===== 一次性获取所有系统服务状态 =====
    local service_list=$(systemctl list-units --all --no-pager --no-legend 2>/dev/null | grep -E 'frpc|frps' | awk '{print $1}')
    
    # 先处理所有系统服务
    for service_unit in $service_list; do
        local service_name=${service_unit%.service}
        
        if [[ "$service_name" =~ ^frpc[2-3]?$ ]] || [[ "$service_name" == "frps" ]]; then
            local pid=$(systemctl show -p MainPID "$service_name" 2>/dev/null | cut -d= -f2)
            local active_state=$(systemctl is-active "$service_name" 2>/dev/null)
            
            if [ -n "$pid" ] && [ "$pid" != "0" ]; then
                service_pids+=("$pid")
            fi
            
            if [ "$active_state" = "active" ]; then
                has_frp=1
                local mem=$(systemctl show -p MemoryCurrent "$service_name" 2>/dev/null | awk '{printf "%.0fM", $1/1024/1024}')
                local config="frpc.toml"
                
                if [[ "$service_name" == "frps" ]]; then
                    config="frps.toml"
                else
                    local exec_start=$(systemctl show -p ExecStart "$service_name" 2>/dev/null)
                    config=$(echo "$exec_start" | grep -o 'frpc[^ ]*\.toml' || echo "${service_name}.toml")
                fi
                
                echo -e "${GREEN}✅ ${service_name}   运行中    PID: ${pid}    内存: ${mem:-0M}    配置: ${config}${NC}"
            else
                echo -e "${RED}❌ ${service_name}   已停止${NC}"
                has_frp=1
            fi
        fi
    done
    
    # ===== 检查手动进程（排除系统服务PID）=====
    local frp_processes=$(pgrep -f "frp[c|s].*toml" | grep -v grep)
    
    if [ -n "$frp_processes" ]; then
        for pid in $frp_processes; do
            # 如果这个PID不在系统服务列表中，才显示为手动进程
            if [[ ! " ${service_pids[@]} " =~ " ${pid} " ]]; then
                has_frp=1
                local cmd=$(ps -p "$pid" -o cmd= 2>/dev/null)
                local config=$(echo "$cmd" | grep -o 'frpc[^ ]*\.toml' || echo "未知")
                local service_type="frpc"
                
                if [[ "$cmd" == *"frps"* ]]; then
                    service_type="frps"
                fi
                
                echo -e "${BLUE}🔄 ${service_type}(手动)    PID: ${pid}    配置: ${config}${NC}"
            fi
        done
    fi
    
    if [ $has_frp -eq 0 ]; then
        echo -e "${YELLOW}⚠ 未检测到 FRP 服务${NC}"
    fi
    
    # ===== 端口信息（快速获取）=====
    local ports=$(ss -tulpn 2>/dev/null | grep frp | awk '{print $5}' | cut -d: -f2 | sort -u | tr '\n' ' ' | sed 's/ $//')
    if [ -n "$ports" ]; then
        echo -e "${BLUE}📌 监听端口: ${ports:-无}${NC}"
    fi
    
    # ===== FRPS配置信息显示（只显示访问地址，不显示配置详情）=====
    if [ -n "$INSTALLED_VERSION" ]; then
        local frp_dir="$FRP_BASE_DIR/frp_${INSTALLED_VERSION}_${ARCH}"
        if [ -f "$frp_dir/frps.toml" ]; then
            echo -e "\n${YELLOW}━━━━━━━━━━━━━ FRPS 访问地址 ━━━━━━━━━━━━━${NC}"
            
            # 获取web控制台端口
            local web_port=$(grep -E "webServer.*port" "$frp_dir/frps.toml" 2>/dev/null | awk -F'=' '{print $2}' | tr -d ' "' | head -1)
            [ -z "$web_port" ] && web_port="7500"
            
            # 获取本机IP地址
            local local_ips=$(hostname -I 2>/dev/null | awk '{print $1}')
            [ -z "$local_ips" ] && local_ips=$(ip addr show 2>/dev/null | grep -oE 'inet (192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]+\.[0-9]+)' | head -1 | awk '{print $2}')
            
            if [ -n "$local_ips" ]; then
                echo -e "${GREEN}🌐 内网访问地址:${NC}"
                for ip in $local_ips; do
                    echo -e "  ➤ http://${ip}:${web_port}"
                done
            fi
            
            # 尝试获取公网IP
            local public_ip=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || curl -s --connect-timeout 3 ipinfo.io/ip 2>/dev/null)
            
            if [ -n "$public_ip" ] && [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo -e "${GREEN}🌍 公网访问地址:${NC}"
                echo -e "  ➤ http://${public_ip}:${web_port}"
            fi
        fi
    fi
    
    # ===== 当前版本 =====
    if [ -n "$INSTALLED_VERSION" ]; then
        echo -e "\n${BLUE}📦 FRP版本: $INSTALLED_VERSION${NC}"
    fi
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ============ 配置FRPC（支持多实例） ============
configure_frpc() {
    local instance=$1
    local config_file="frpc.toml"
    local service_name="frpc"
    
    if [ "$instance" = "2" ]; then
        config_file="frpc2.toml"
        service_name="frpc2"
        echo -e "\n${PURPLE}════ 配置第二个 FRPC 实例 ════${NC}"
    elif [ "$instance" = "3" ]; then
        config_file="frpc3.toml"
        service_name="frpc3"
        echo -e "\n${PURPLE}════ 配置第三个 FRPC 实例 ════${NC}"
    else
        echo -e "\n${GREEN}════ 配置 FRPC 实例 ════${NC}"
    fi
    
    read -p "请输入服务器地址: " SERVER_ADDR
    if [ -z "$SERVER_ADDR" ]; then
        echo -e "${RED}服务器地址不能为空${NC}"
        return 1
    fi
    
    read -p "请输入服务器端口 [默认7000]: " SERVER_PORT
    [ -z "$SERVER_PORT" ] && SERVER_PORT=7000
    
    read -p "请输入本地端口: " LOCAL_PORT
    if [ -z "$LOCAL_PORT" ]; then
        echo -e "${RED}本地端口不能为空${NC}"
        return 1
    fi
    
    read -p "请输入远程端口: " REMOTE_PORT
    if [ -z "$REMOTE_PORT" ]; then
        echo -e "${RED}远程端口不能为空${NC}"
        return 1
    fi
    
    read -p "请输入 token (默认 '***12345678***'): " TOKEN
    [ -z "$TOKEN" ] && TOKEN="***12345678***"
    
    read -p "请输入代理名称 (默认: tcp_proxy${instance}): " PROXY_NAME
    [ -z "$PROXY_NAME" ] && PROXY_NAME="tcp_proxy${instance}"
    
    # 询问 loginFailExit 设置 - 改进版
    echo -e "\n${YELLOW}首次登录失败后是否退出程序？${NC}"
    echo "1. 持续重连直到成功 - 不退出 (默认)"
    echo "2. 失败即停止 - 退出程序"
    
    while true; do
        read -p "请选择 [1-2] (直接回车默认1): " LOGIN_FAIL_CHOICE
        if [ -z "$LOGIN_FAIL_CHOICE" ]; then
            LOGIN_FAIL_CHOICE="1"
            break
        fi
        if [[ "$LOGIN_FAIL_CHOICE" =~ ^[1-2]$ ]]; then
            break
        else
            echo -e "${RED}请输入 1 或 2${NC}"
        fi
    done
    
    if [ "$LOGIN_FAIL_CHOICE" = "1" ]; then
        LOGIN_FAIL_EXIT="false"
        echo -e "${GREEN}✅ 已选择: 持续重连模式${NC}"
    else
        LOGIN_FAIL_EXIT="true"
        echo -e "${GREEN}✅ 已选择: 失败即停止模式${NC}"
    fi

    # 标准TOML格式
    cat > "$config_file" <<EOL
# FRPC 配置文件 - ${config_file}
serverAddr = "${SERVER_ADDR}"
serverPort = ${SERVER_PORT}

# 首次登录失败后是否退出程序
# false: 不退出，持续重连； true: 失败即退出（默认）
loginFailExit = ${LOGIN_FAIL_EXIT}

auth.method = "token"
auth.token = "${TOKEN}"

log.to = "./${config_file}.log"
log.level = "info"
log.maxDays = 3

[[proxies]]
name = "${PROXY_NAME}"
type = "tcp"
localIP = "127.0.0.1"
localPort = ${LOCAL_PORT}
remotePort = ${REMOTE_PORT}
EOL

    echo -e "${GREEN}✅ $config_file 配置完成${NC}"
    
    # 使用统一的confirm函数，默认Y
    if confirm_yes_no "是否配置为系统服务并开机自启?" "Y"; then
        local INSTALL_PATH=$(pwd)

        cat > "/etc/systemd/system/${service_name}.service" <<EOL
[Unit]
Description=FRPC Service - ${config_file}
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStart=${INSTALL_PATH}/frpc -c ${INSTALL_PATH}/${config_file}
ExecStop=/bin/kill -TERM \$MAINPID
WorkingDirectory=${INSTALL_PATH}

[Install]
WantedBy=multi-user.target
EOL

        systemctl daemon-reload
        systemctl enable ${service_name}
        systemctl start ${service_name}

        echo -e "${GREEN}✅ $service_name 已配置为系统服务并启动${NC}"
    else
        if pgrep -f "./frpc -c ./${config_file}" > /dev/null; then
            pkill -f "./frpc -c ./${config_file}"
            sleep 2
        fi
        nohup ./frpc -c "./${config_file}" > "${config_file}.nohup.log" 2>&1 &
        echo -e "${GREEN}✅ FRPC 已启动（非服务模式），配置: $config_file${NC}"
    fi
}

# ============ 配置FRPS ============
configure_frps() {
    echo -e "\n${GREEN}════ 配置 FRPS 服务端 ════${NC}"
    
    read -p "请输入 FRPS 监听端口 [默认7000]: " FRPS_PORT
    [ -z "$FRPS_PORT" ] && FRPS_PORT=7000

    read -p "请输入控制台用户名 [默认admin]: " AUTH_USER
    [ -z "$AUTH_USER" ] && AUTH_USER="admin"
    
    read -p "请输入控制台密码 [默认admin]: " AUTH_PASS
    [ -z "$AUTH_PASS" ] && AUTH_PASS="admin"
    
    read -p "请输入 token (默认 '***12345678***'): " TOKEN
    [ -z "$TOKEN" ] && TOKEN="***12345678***"

    cat > frps.toml <<EOL
# FRPS 配置文件
bindAddr = "0.0.0.0"
bindPort = ${FRPS_PORT}

auth.method = "token"
auth.token = "${TOKEN}"

log.to = "./frps.log"
log.level = "info"
log.maxDays = 1

webServer.addr = "0.0.0.0"
webServer.port = 7500
webServer.user = "${AUTH_USER}"
webServer.password = "${AUTH_PASS}"
EOL

    echo -e "${GREEN}✅ frps.toml 配置完成${NC}"

    # 使用统一的confirm函数，默认Y
    if confirm_yes_no "是否配置为系统服务并开机自启?" "Y"; then
        local INSTALL_PATH=$(pwd)

        cat > /etc/systemd/system/frps.service <<EOL
[Unit]
Description=FRPS Service
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStart=${INSTALL_PATH}/frps -c ${INSTALL_PATH}/frps.toml
ExecStop=/bin/kill -TERM \$MAINPID
WorkingDirectory=${INSTALL_PATH}

[Install]
WantedBy=multi-user.target
EOL

        systemctl daemon-reload
        systemctl enable frps
        systemctl start frps

        echo -e "${GREEN}✅ frps 已配置为系统服务并启动${NC}"
    else
        if pgrep -f "./frps -c ./frps.toml" > /dev/null; then
            pkill -f "./frps -c ./frps.toml"
            sleep 2
        fi
        nohup ./frps -c ./frps.toml > frps.nohup.log 2>&1 &
        echo -e "${GREEN}✅ FRPS 已启动（非服务模式）${NC}"
    fi
    
    # 显示配置信息
    echo -e "\n${YELLOW}════════════════ FRPS 配置完成 ════════════════${NC}"
    
    # 获取本机IP地址
    local local_ips=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$local_ips" ] && local_ips=$(ip addr show 2>/dev/null | grep -oE 'inet (192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]+\.[0-9]+)' | head -1 | awk '{print $2}')
    
    if [ -n "$local_ips" ]; then
        echo -e "${GREEN}🌐 内网访问地址:${NC}"
        for ip in $local_ips; do
            echo -e "  ➤ http://${ip}:7500"
        done
    fi
    
    # 尝试获取公网IP
    local public_ip=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null)
    
    if [ -n "$public_ip" ] && [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${GREEN}🌍 公网访问地址:${NC}"
        echo -e "  ➤ http://${public_ip}:7500"
    fi
    
    echo -e "\n${YELLOW}📋 重要提示:${NC}"
    echo "1. 请确保防火墙已开放端口: 7500"
    echo "2. 路由器需要设置端口转发: 外部7500 → 本机IP:7500"
    echo -e "\n${GREEN}📊 您可以在主菜单选择'4.查看 FRP 服务状态'查看访问信息${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════${NC}"
}

# ============ 配置和启动FRP主菜单 ============
configure_and_start_frp() {
    if ! enter_frp_workdir; then
        echo -e "${YELLOW}请先安装FRP（选项8）${NC}"
        return 1
    fi
    
    echo -e "\n${YELLOW}════════════════ FRP 配置菜单 ════════════════${NC}"
    echo "1. 配置 FRPC (客户端)"
    echo "2. 配置 FRPC2 (第二个客户端)"
    echo "3. 配置 FRPC3 (第三个客户端)"
    echo "4. 配置 FRPS (服务端)"
    echo "5. 返回主菜单"
    
    read -p "请选择 [1-5]: " FRP_CHOICE
    
    case $FRP_CHOICE in
        1) configure_frpc "1" ;;
        2) configure_frpc "2" ;;
        3) configure_frpc "3" ;;
        4) configure_frps ;;
        5) return ;;
        *) echo -e "${RED}无效选择${NC}" ;;
    esac
}

# ============ 服务管理 ============
restart_service() {
    local service_name=$1
    echo -e "${YELLOW}正在重启 $service_name 服务...${NC}"
    systemctl restart $service_name 2>/dev/null
    sleep 1
    if systemctl is-active --quiet $service_name 2>/dev/null; then
        echo -e "${GREEN}✅ $service_name 已重启${NC}"
    else
        echo -e "${RED}❌ $service_name 重启失败${NC}"
    fi
}

stop_service() {
    local service_name=$1
    echo -e "${YELLOW}正在停止 $service_name 服务...${NC}"
    systemctl stop $service_name 2>/dev/null
    sleep 1
    if systemctl is-active --quiet $service_name 2>/dev/null; then
        echo -e "${RED}❌ $service_name 停止失败${NC}"
    else
        echo -e "${GREEN}✅ $service_name 已停止${NC}"
    fi
}

uninstall_frp_service() {
    local service_name=$1
    echo -e "${YELLOW}正在卸载 $service_name 服务...${NC}"
    systemctl stop $service_name 2>/dev/null
    systemctl disable $service_name 2>/dev/null
    rm -f "/etc/systemd/system/${service_name}.service"
    systemctl daemon-reload
    pkill -f "./${service_name}" 2>/dev/null
    echo -e "${GREEN}✅ $service_name 服务已卸载${NC}"
}

# ============ 配置文件管理（支持多客户端） ============
manage_config() {
    if ! enter_frp_workdir; then
        return 1
    fi
    
    echo -e "\n${YELLOW}════════════════ 配置文件管理 ════════════════${NC}"
    
    local configs=()
    local i=1
    
    for cfg in frpc*.toml frps.toml; do
        if [ -f "$cfg" ]; then
            configs+=("$cfg")
            echo -e "${GREEN}$i. $cfg${NC}"
            ((i++))
        fi
    done
    
    if [ ${#configs[@]} -eq 0 ]; then
        echo -e "${YELLOW}未找到配置文件，请先配置FRP${NC}"
        return 1
    fi
    
    echo -e "${GREEN}$i. 备份所有配置文件${NC}"
    echo -e "${GREEN}$((i+1)). 返回主菜单${NC}"
    
    read -p "请选择要编辑的配置文件: " CONFIG_CHOICE
    
    if [ "$CONFIG_CHOICE" -eq "$i" ]; then
        local backup_dir="$FRP_BASE_DIR/backups"
        mkdir -p "$backup_dir"
        local backup_time=$(date +%Y%m%d_%H%M%S)
        
        for cfg in "${configs[@]}"; do
            cp "$cfg" "$backup_dir/${cfg}.${backup_time}"
            echo -e "${GREEN}✅ $cfg 已备份${NC}"
        done
        echo -e "${GREEN}备份路径: $backup_dir${NC}"
        
    elif [ "$CONFIG_CHOICE" -eq "$((i+1))" ]; then
        return
        
    elif [[ "$CONFIG_CHOICE" =~ ^[0-9]+$ ]] && [ "$CONFIG_CHOICE" -ge 1 ] && [ "$CONFIG_CHOICE" -le ${#configs[@]} ]; then
        local selected_config="${configs[$((CONFIG_CHOICE-1))]}"
        local service_name=$(basename "$selected_config" .toml)
        
        cp "$selected_config" "${selected_config}.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}已创建备份${NC}"
        
        nano -w "$selected_config"
        
        # 使用统一的confirm函数，默认N
        if confirm_yes_no "是否重启对应的服务?" "N"; then
            if systemctl list-unit-files 2>/dev/null | grep -q "$service_name"; then
                systemctl restart "$service_name"
                echo -e "${GREEN}✅ $service_name 已重启${NC}"
            else
                pkill -f "./frpc -c ./${selected_config}"
                nohup ./frpc -c "./${selected_config}" > "${selected_config}.nohup.log" 2>&1 &
                echo -e "${GREEN}✅ FRPC 已重启，配置: $selected_config${NC}"
            fi
        fi
    else
        echo -e "${RED}无效的选择${NC}"
    fi
}

# ============ 查看日志（支持多客户端） ============
view_logs() {
    if ! enter_frp_workdir; then
        return 1
    fi
    
    echo -e "\n${YELLOW}════════════════ FRP 日志查看 ════════════════${NC}"
    
    local logs=()
    local i=1
    
    for log in frpc*.log frps.log; do
        if [ -f "$log" ]; then
            logs+=("$log")
            echo -e "${GREEN}$i. $log${NC}"
            ((i++))
        fi
    done
    
    if [ ${#logs[@]} -eq 0 ]; then
        echo -e "${YELLOW}未找到日志文件${NC}"
        for service in frps frpc frpc2 frpc3; do
            if systemctl list-unit-files 2>/dev/null | grep -q "$service"; then
                echo -e "\n${BLUE}=== $service 服务日志 ===${NC}"
                journalctl -u "$service" --no-pager -n 20
            fi
        done
        return
    fi
    
    echo -e "${GREEN}$i. 返回主菜单${NC}"
    
    read -p "请选择要查看的日志: " LOG_CHOICE
    
    if [[ "$LOG_CHOICE" =~ ^[0-9]+$ ]] && [ "$LOG_CHOICE" -ge 1 ] && [ "$LOG_CHOICE" -le ${#logs[@]} ]; then
        local selected_log="${logs[$((LOG_CHOICE-1))]}"
        echo -e "${GREEN}实时查看 $selected_log (按 Ctrl+C 退出)${NC}"
        tail -f "$selected_log"
    fi
}

# ============ 版本管理菜单 ============
version_management() {
    echo -e "\n${YELLOW}════════════════ FRP 版本管理 ════════════════${NC}"
    echo "1. 检查更新"
    echo "2. 指定版本安装"
    echo "3. 版本回滚"
    echo "4. 返回主菜单"
    
    read -p "请选择 [1-4]: " VER_CHOICE
    
    case $VER_CHOICE in
        1)
            echo -e "\n${GREEN}正在检查更新...${NC}"
            local latest_version=$(curl -s --connect-timeout 5 https://api.github.com/repos/fatedier/frp/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
            
            if [ -z "$latest_version" ]; then
                echo -e "${RED}无法获取最新版本信息${NC}"
                return
            fi
            
            echo -e "当前版本: ${GREEN}${INSTALLED_VERSION:-未安装}${NC}"
            echo -e "最新版本: ${GREEN}$latest_version${NC}"
            
            if [ "$INSTALLED_VERSION" != "$latest_version" ]; then
                echo -e "${YELLOW}发现新版本!${NC}"
                if confirm_yes_no "是否现在升级?" "N"; then
                    upgrade_frp "$latest_version"
                fi
            else
                echo -e "${GREEN}已是最新版本${NC}"
            fi
            ;;
        2)
            read -p "请输入要安装的FRP版本 (如 0.69.0): " CUSTOM_VERSION
            if [ -z "$CUSTOM_VERSION" ]; then
                echo -e "${RED}版本号不能为空${NC}"
                return
            fi
            
            if [ "$CUSTOM_VERSION" = "$INSTALLED_VERSION" ]; then
                echo -e "${YELLOW}当前已是此版本${NC}"
                return
            fi
            
            if [ -d "$FRP_BASE_DIR/frp_${CUSTOM_VERSION}_${ARCH}" ]; then
                echo -e "${YELLOW}版本 $CUSTOM_VERSION 已存在${NC}"
                if confirm_yes_no "是否切换到该版本?" "N"; then
                    echo "$CUSTOM_VERSION" > "$VERSION_FILE"
                    INSTALLED_VERSION="$CUSTOM_VERSION"
                    echo -e "${GREEN}已切换到版本: $CUSTOM_VERSION${NC}"
                fi
            else
                download_frp_once "$CUSTOM_VERSION"
                echo "$CUSTOM_VERSION" > "$VERSION_FILE"
                INSTALLED_VERSION="$CUSTOM_VERSION"
            fi
            ;;
        3)
            rollback_frp
            ;;
        4)
            return
            ;;
    esac
}

# ============ 显示系统信息 ============
show_system_info() {
    echo -e "\n${YELLOW}════════════════ 系统信息 ════════════════${NC}"
    echo "系统架构: $(uname -m)"
    echo "操作系统: $(uname -s)"
    echo "内核版本: $(uname -r)"
    echo "主机名: $(hostname)"
    echo "当前用户: $(whoami)"
    echo "FRP安装目录: $FRP_BASE_DIR"
    echo "FRP当前版本: ${INSTALLED_VERSION:-未安装}"
    echo "脚本版本: $SCRIPT_VERSION"
    echo ""
    echo "磁盘使用:"
    df -h "$FRP_BASE_DIR" | tail -1 | awk '{print "  " $1 " " $2 " " $3 " " $4 " " $5}'
    echo ""
    echo "内存使用:"
    free -h | grep -E "^(Mem|Swap)" | awk '{print "  " $1 " 总内存:" $2 " 已用:" $3 " 可用:" $4}'
    
    if [ -n "$INSTALLED_VERSION" ] && [ -d "$FRP_BASE_DIR/frp_${INSTALLED_VERSION}_${ARCH}" ]; then
        echo ""
        echo "FRP配置文件:"
        local cfg_dir="$FRP_BASE_DIR/frp_${INSTALLED_VERSION}_${ARCH}"
        for cfg in "$cfg_dir"/frpc*.toml "$cfg_dir"/frps.toml; do
            if [ -f "$cfg" ]; then
                echo "  📄 $(basename "$cfg")"
            fi
        done
    fi
    
    echo -e "${YELLOW}════════════════════════════════════════════${NC}"
}

# ============ 主菜单 ============
show_menu() {
    clear
    echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${YELLOW}     FRP 管理脚本 v${SCRIPT_VERSION}                ${YELLOW}║${NC}"
    echo -e "${YELLOW}╠════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  系统架构: ${GREEN}$ARCH${NC}                 ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  安装目录: ${GREEN}$FRP_BASE_DIR${NC}                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  当前版本: ${GREEN}${INSTALLED_VERSION:-未安装}${NC}                      ${YELLOW}║${NC}"
    echo -e "${YELLOW}╠════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}1.${NC} 配置并启动 FRP 服务（支持多实例）  ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}2.${NC} 重启 FRP 服务                      ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}3.${NC} 停止 FRP 服务                      ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}4.${NC} 查看 FRP 服务状态                  ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}5.${NC} 卸载 FRP 服务                      ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}6.${NC} 编辑配置文件                       ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}7.${NC} 查看 FRP 日志                      ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}8.${NC} 版本管理（升级/回滚）              ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}9.${NC} 显示系统信息                       ${YELLOW}║${NC}"
	echo -e "${YELLOW}║${NC}  ${GREEN}10.${NC} 安装为全局命令 frp                ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}0.${NC} 退出                               ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
    echo ""
}

install_command() {
    echo -e "${YELLOW}正在安装全局命令 frp...${NC}"

    if [ ! -f "$0" ]; then
        echo -e "${RED}无法找到当前脚本路径${NC}"
        return 1
    fi

    cp "$0" /usr/local/bin/frp
    chmod +x /usr/local/bin/frp

    if [ -f "/usr/local/bin/frp" ]; then
        echo -e "${GREEN}✅ 安装成功！${NC}"
        echo -e "${GREEN}👉 现在可以直接输入: frp${NC}"
    else
        echo -e "${RED}❌ 安装失败${NC}"
    fi
}

# ============ 主函数 ============
main() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}请以root权限运行此脚本${NC}"
        echo "使用: sudo $0"
        exit 1
    fi
    
    for cmd in curl tar systemctl nano; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}未找到命令: $cmd${NC}"
            exit 1
        fi
    done
    
    init_environment
    
    if [ -z "$INSTALLED_VERSION" ]; then
        echo -e "${YELLOW}首次运行，自动下载稳定版本 FRP $DEFAULT_VERSION${NC}"
        download_frp_once "$DEFAULT_VERSION"
        echo "$DEFAULT_VERSION" > "$VERSION_FILE"
        INSTALLED_VERSION="$DEFAULT_VERSION"
    fi
    
    while true; do
        show_menu
        read -p "请选择操作 [0-9]: " MAIN_CHOICE
        
        case $MAIN_CHOICE in
            1)
                configure_and_start_frp
                continue
                ;;
            2)
                echo -e "\n${YELLOW}可重启的服务: frpc frpc2 frpc3 frps${NC}"
                read -p "请输入要重启的服务名称: " SERVICE_NAME
                if [[ "$SERVICE_NAME" =~ ^(frpc|frpc2|frpc3|frps)$ ]]; then
                    restart_service $SERVICE_NAME
                else
                    echo -e "${RED}无效的服务名称${NC}"
                fi
                continue
                ;;
            3)
                echo -e "\n${YELLOW}可停止的服务: frpc frpc2 frpc3 frps${NC}"
                read -p "请输入要停止的服务名称: " SERVICE_NAME
                if [[ "$SERVICE_NAME" =~ ^(frpc|frpc2|frpc3|frps)$ ]]; then
                    stop_service $SERVICE_NAME
                else
                    echo -e "${RED}无效的服务名称${NC}"
                fi
                continue
                ;;
            4)
                quick_status
                ;;
            5)
                echo -e "\n${YELLOW}可卸载的服务: frpc frpc2 frpc3 frps${NC}"
                read -p "请输入要卸载的服务名称: " SERVICE_NAME
                if [[ "$SERVICE_NAME" =~ ^(frpc|frpc2|frpc3|frps)$ ]]; then
                    uninstall_frp_service $SERVICE_NAME
                else
                    echo -e "${RED}无效的服务名称${NC}"
                fi
                continue
                ;;
            6)
                manage_config
                continue
                ;;
            7)
                view_logs
                continue
                ;;
            8)
                version_management
                continue
                ;;
            9)
                show_system_info
                ;;
			10)
                install_command
                ;;
            0)
                echo -e "${GREEN}感谢使用 FRP 管理脚本！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选择${NC}"
                sleep 1
                continue
                ;;
        esac
                
        echo
        read -p "按 Enter 键继续..."
    done
}

# ============ 启动脚本 ============
main "$@"
