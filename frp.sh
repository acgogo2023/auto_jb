#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 没有颜色

# 检测系统架构
detect_architecture() {
    local arch
    arch=$(uname -m)
    
    case $arch in
        x86_64)
            echo "linux_amd64"
            ;;
        aarch64|arm64)
            echo "linux_arm64"
            ;;
        armv7l|armv6l)
            echo "linux_arm"
            ;;
        i386|i686)
            echo "linux_386"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# 获取架构信息
ARCH=$(detect_architecture)
echo -e "${GREEN}检测到系统架构: $ARCH${NC}"

if [ "$ARCH" = "unknown" ]; then
    echo -e "${RED}不支持的系统架构，脚本退出${NC}"
    exit 1
fi

# 定义下载地址
INTERNATIONAL_DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/v"
DOMESTIC_DOWNLOAD_URL="https://gitee.com/git220/frp/releases/download/v"

# 提示用户选择下载地址
echo -e "${YELLOW}请选择下载地址：${NC}"
echo "1. 国内 (Gitee)"
echo "2. 国际 (GitHub)"
while true; do
    read -p "请输入 1 或 2 (直接回车默认选择1): " DOWNLOAD_CHOICE
    # 如果用户直接回车，设置默认值为1
    if [ -z "$DOWNLOAD_CHOICE" ]; then
        DOWNLOAD_CHOICE="1"
        echo -e "${GREEN}已选择默认选项: 1${NC}"
        break
    fi
    if [ "$DOWNLOAD_CHOICE" = "1" ] || [ "$DOWNLOAD_CHOICE" = "2" ]; then
        break
    else
        echo -e "${RED}无效的输入，请输入 1 或 2。${NC}"
    fi
done

# 设置下载地址.
if [ "$DOWNLOAD_CHOICE" = "1" ]; then
    DOWNLOAD_BASE_URL="${DOMESTIC_DOWNLOAD_URL}"
else
    DOWNLOAD_BASE_URL="${INTERNATIONAL_DOWNLOAD_URL}"
fi

# 检查最新版本
LATEST_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
DEFAULT_VERSION="0.65.0"

# 提示用户选择版本
echo -e "${YELLOW}是否使用最新版本 FRP？(默认使用 $DEFAULT_VERSION，输入 yes 使用最新版)${NC}"
read -p "请输入 yes 或直接按 Enter 使用默认版本: " USE_LATEST

# 设置版本选择逻辑：默认使用 0.65.0，只有明确输入 yes 才用最新版
if [ "$USE_LATEST" = "yes" ]; then
    FRP_VERSION=$LATEST_VERSION
    echo -e "${GREEN}已选择使用最新版本: $FRP_VERSION${NC}"
else
    FRP_VERSION=$DEFAULT_VERSION
    echo -e "${GREEN}使用默认版本: $FRP_VERSION${NC}"
fi

# 根据架构定义文件名
FRP_TAR="frp_${FRP_VERSION}_${ARCH}.tar.gz"
FRP_DIR="frp_${FRP_VERSION}_${ARCH}"

# 完整下载地址
DOWNLOAD_URL="${DOWNLOAD_BASE_URL}${FRP_VERSION}/${FRP_TAR}"

echo -e "${GREEN}准备下载: $FRP_TAR${NC}"
echo -e "${GREEN}下载地址: $DOWNLOAD_URL${NC}"

# 检查是否已下载FRP文件
if [ ! -f "$FRP_TAR" ]; then
    echo -e "${GREEN}正在下载 FRP ${FRP_VERSION} (${ARCH})...${NC}"
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
if [ ! -d "$FRP_DIR" ]; then
    echo -e "${RED}错误：解压目录 $FRP_DIR 不存在${NC}"
    exit 1
fi
echo -e "${GREEN}正在进入目录: $FRP_DIR${NC}"
cd $FRP_DIR || {
    echo -e "${RED}进入目录失败${NC}"
    exit 1
}

# 显示主菜单
show_menu() {
    echo -e "\n${YELLOW}===== FRP 管理菜单 (${ARCH}) =====${NC}"
    echo "1. 配置和启动 FRP 服务"
    echo "2. 重启 FRP 服务"
    echo "3. 停止 FRP 服务"
    echo "4. 查看 FRP 服务状态"
    echo "5. 卸载 FRP 服务"
    echo "6. 配置文件 查看\编辑\备份"
    echo "7. 显示系统信息"
    echo "8. 退出"
    echo -e "${YELLOW}====================================${NC}\n"
}

# 显示系统信息函数
show_system_info() {
    echo -e "\n${YELLOW}===== 系统信息 =====${NC}"
    echo "系统架构: $(uname -m)"
    echo "操作系统: $(uname -s)"
    echo "内核版本: $(uname -r)"
    echo "主机名: $(hostname)"
    echo "当前用户: $(whoami)"
    echo "当前目录: $(pwd)"
    echo "FRP 版本: $FRP_VERSION"
    echo "FRP 架构: $ARCH"
    echo -e "${YELLOW}===================${NC}"
}

# 检查服务状态函数
check_service_status() {
    local service_name=$1
    if systemctl is-active --quiet $service_name; then
        echo -e "${GREEN}$service_name 服务正在运行${NC}"
        return 0
    else
        echo -e "${RED}$service_name 服务未运行${NC}"
        return 1
    fi
}

# 重启服务函数
restart_service() {
    local service_name=$1
    echo -e "${YELLOW}正在重启 $service_name 服务...${NC}"
    systemctl restart $service_name
    sleep 2
    check_service_status $service_name
}

# 停止服务函数
stop_service() {
    local service_name=$1
    echo -e "${YELLOW}正在停止 $service_name 服务...${NC}"
    systemctl stop $service_name
    if systemctl is-active --quiet $service_name; then
        echo -e "${RED}$service_name 服务停止失败${NC}"
        return 1
    else
        echo -e "${GREEN}$service_name 服务已停止${NC}"
        return 0
    fi
}

# 卸载服务函数
uninstall_service() {
    local service_name=$1
    echo -e "${YELLOW}正在彻底卸载 $service_name 服务...${NC}"
    
    # 1. 停止服务
    echo -e "${GREEN}步骤1: 停止 $service_name 服务...${NC}"
    systemctl stop $service_name 2>/dev/null && echo -e "  - 服务已停止。" || echo -e "  - 服务未运行或停止出错。"
    
    # 2. 禁用服务
    echo -e "${GREEN}步骤2: 禁用 $service_name 服务...${NC}"
    systemctl disable $service_name 2>/dev/null && echo -e "  - 服务已禁用。" || echo -e "  - 禁用服务时出错。"
    
    # 3. 强制杀死所有相关的 FRP 进程
    echo -e "${GREEN}步骤3: 清理残留进程...${NC}"
    local pkill_result=$(pkill -9 -f ".*$service_name.*" 2>&1)
    sleep 1
    local pgrep_result=$(pgrep -f ".*$service_name.*" 2>&1)
    if [ -n "$pgrep_result" ]; then
        echo -e "  - 警告：发现残留进程(PID: $pgrep_result)，强制杀死。"
        kill -9 $pgrep_result 2>/dev/null
        sleep 1
    else
        echo -e "  - 无残留进程。"
    fi
    
    # 4. 删除 systemd 服务文件
    echo -e "${GREEN}步骤4: 删除服务配置文件...${NC}"
    local service_file="/etc/systemd/system/${service_name}.service"
    if [ -f "$service_file" ]; then
        rm -f "$service_file" && echo -e "  - 服务文件 $service_file 已删除。"
    else
        echo -e "  - 服务文件 $service_file 不存在。"
    fi
    
    # 5. 重新加载 systemd 配置
    echo -e "${GREEN}步骤5: 重新加载 systemd 配置...${NC}"
    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null
    echo -e "  - Systemd 配置已重载。"
    
    echo -e "${GREEN}$service_name 服务已彻底卸载完成。${NC}"
    echo -e "${YELLOW}提示：FRP 程序文件仍保留在当前目录，如需重新配置可直接运行脚本。${NC}"
}

# 创建备份目录函数
create_backup_dir() {
    local backup_dir="/root/frp_backups"
    
    if [ ! -d "$backup_dir" ]; then
        mkdir -p "$backup_dir"
        echo -e "${GREEN}创建备份目录: $backup_dir${NC}"
    fi
    echo "$backup_dir"
}

# 备份配置文件函数（简化版 - 直接覆盖）
backup_config_file() {
    local config_file=$1
    local backup_dir=$(create_backup_dir)
    local backup_file="${backup_dir}/${config_file}"
    
    # 直接复制覆盖，不询问
    cp "$config_file" "$backup_file"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}配置文件已备份: $backup_file${NC}"
        return 0
    else
        echo -e "${RED}备份失败${NC}"
        return 1
    fi
}

# 恢复备份文件函数（简化版）
restore_backup_file() {
    local config_file=$1
    local backup_dir="/root/frp_backups"
    local backup_file="${backup_dir}/${config_file}"
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}备份文件不存在: $backup_file${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}备份文件内容预览:${NC}"
    echo "----------------------------------------"
    head -n 10 "$backup_file"
    echo "----------------------------------------"
    
    read -p "确定要恢复此备份吗? (yes/no): " confirm_restore
    if [ "$confirm_restore" = "yes" ]; then
        cp "$backup_file" "$config_file"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}配置文件恢复成功${NC}"
            
            # 验证配置文件语法
            validate_config_file "$config_file"
            
            # 询问是否重启服务
            if [[ "$config_file" == *"frpc"* ]]; then
                read -p "是否要重启frpc服务以使配置生效? (yes/no): " restart_choice
                if [ "$restart_choice" = "yes" ]; then
                    restart_service "frpc"
                fi
            elif [[ "$config_file" == *"frps"* ]]; then
                read -p "是否要重启frps服务以使配置生效? (yes/no): " restart_choice
                if [ "$restart_choice" = "yes" ]; then
                    restart_service "frps"
                fi
            fi
            return 0
        else
            echo -e "${RED}配置文件恢复失败${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}已取消恢复操作${NC}"
        return 2
    fi
}

# 验证配置文件函数
validate_config_file() {
    local config_file=$1
    
    echo -e "\n${YELLOW}配置文件语法检查:${NC}"
    
    # 基本检查：文件是否存在且非空
    if [ ! -s "$config_file" ]; then
        echo -e "${RED}错误: 配置文件为空或不存在${NC}"
        return 1
    fi
    
    # 检查文件格式（基本TOML格式检查）
    if grep -q "\[.*\]" "$config_file" && grep -q "=" "$config_file"; then
        echo -e "${GREEN}✓ 基本TOML格式正确${NC}"
    else
        echo -e "${YELLOW}⚠ 配置文件可能不符合TOML格式${NC}"
    fi
    
    # 检查常见配置错误
    local error_found=0
    
    # 检查是否有未闭合的括号
    local open_brackets=$(grep -o '\[' "$config_file" | wc -l)
    local close_brackets=$(grep -o '\]' "$config_file" | wc -l)
    if [ "$open_brackets" -ne "$close_brackets" ]; then
        echo -e "${RED}✗ 括号不匹配: 开始括号[$open_brackets] ≠ 结束括号[$close_brackets]${NC}"
        ((error_found++))
    else
        echo -e "${GREEN}✓ 括号匹配正确${NC}"
    fi
    
    if [ $error_found -eq 0 ]; then
        echo -e "${GREEN}配置文件语法检查通过${NC}"
    else
        echo -e "${YELLOW}发现 $error_found 个潜在问题，请仔细检查配置${NC}"
    fi
}

# 使用nano编辑配置文件函数（优化版）
edit_config_with_nano() {
    echo -e "\n${YELLOW}===== 使用nano编辑配置文件 =====${NC}"
    
    # 动态获取当前目录下的配置文件
    local current_dir=$(pwd)
    local frpc_config="frpc.toml"
    local frps_config="frps.toml"
    
    # 检查配置文件是否存在
    if [ ! -f "$frpc_config" ] && [ ! -f "$frps_config" ]; then
        echo -e "${RED}未找到任何配置文件 (frpc.toml 或 frps.toml)${NC}"
        echo -e "${YELLOW}当前目录: $current_dir${NC}"
        echo -e "${YELLOW}目录内容:${NC}"
        ls -la
        echo -e "${YELLOW}请先运行选项1创建配置文件${NC}"
        return 1
    fi
    
    while true; do
        echo -e "\n${GREEN}可用的配置文件操作:${NC}"
        echo "1. 查看/编辑 frpc.toml (客户端配置)"
        echo "2. 查看/编辑 frps.toml (服务端配置)"
        echo "3. 备份配置文件"
        echo "4. 恢复备份文件"
        echo "5. 返回主菜单"
        
        local main_choice
        read -p "请选择操作 (1-5): " main_choice
        
        case $main_choice in
            1)
                if [ -f "$frpc_config" ]; then
                    edit_with_nano_direct "$frpc_config"
                else
                    echo -e "${RED}frpc.toml 不存在${NC}"
                fi
                ;;
            2)
                if [ -f "$frps_config" ]; then
                    edit_with_nano_direct "$frps_config"
                else
                    echo -e "${RED}frps.toml 不存在${NC}"
                fi
                ;;
            3)  # 新增的独立备份功能
                backup_config_menu
                ;;
            4)
                restore_config_menu
                ;;
            5)
                echo -e "${GREEN}返回主菜单${NC}"
                return 0
                ;;
            *)
                echo -e "${RED}无效的选择${NC}"
                ;;
        esac
    done
}

# 直接编辑配置文件函数（无自动备份）
edit_with_nano_direct() {
    local config_file=$1
    
    # 显示配置文件基本信息
    echo -e "\n${GREEN}配置文件信息:${NC}"
    echo "文件: $config_file"
    echo "大小: $(du -h "$config_file" | cut -f1)"
    echo "行数: $(wc -l < "$config_file")"
    echo "最后修改: $(stat -c %y "$config_file" 2>/dev/null || stat -f %Sm "$config_file")"
    
    # 显示配置文件前10行内容预览
    echo -e "\n${YELLOW}配置文件前30行预览:${NC}"
    echo "----------------------------------------"
    head -n 30 "$config_file"
    echo "----------------------------------------"
    
    # 确认编辑（不再自动备份）
    read -p "确定要使用nano编辑此文件吗? (yes/no): " confirm_edit
    if [ "$confirm_edit" != "yes" ]; then
        echo -e "${YELLOW}已取消编辑${NC}"
        return 0
    fi
    
    # 检查nano是否安装
    if ! command -v nano &> /dev/null; then
        echo -e "${YELLOW}nano未安装，正在尝试安装...${NC}"
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y nano
        elif command -v yum &> /dev/null; then
            sudo yum install -y nano
        else
            echo -e "${RED}无法自动安装nano，请手动安装nano编辑器${NC}"
            return 1
        fi
    fi
    
    # 使用-w选项禁用自动换行
    nano -w "$config_file"
    
    local edit_result=$?
    
    if [ $edit_result -eq 0 ]; then
        echo -e "${GREEN}配置文件编辑完成${NC}"
        
        # 验证配置文件语法
        validate_config_file "$config_file"
        
        # 询问是否重启服务
        if [[ "$config_file" == *"frpc"* ]]; then
            read -p "是否要重启frpc服务以使配置生效? (yes/no): " restart_choice
            if [ "$restart_choice" = "yes" ]; then
                restart_service "frpc"
            fi
        elif [[ "$config_file" == *"frps"* ]]; then
            read -p "是否要重启frps服务以使配置生效? (yes/no): " restart_choice
            if [ "$restart_choice" = "yes" ]; then
                restart_service "frps"
            fi
        fi
    else
        echo -e "${RED}配置文件编辑过程中出现错误${NC}"
        return 1
    fi
}

# 备份配置菜单函数（修复换行符问题）
backup_config_menu() {
    echo -e "\n${YELLOW}===== 备份配置文件 =====${NC}"
    
    # 进入备份菜单循环
    while true; do
        local current_dir=$(pwd)
        local frpc_config="frpc.toml"
        local frps_config="frps.toml"
        
        # 检查配置文件是否存在
        if [ ! -f "$frpc_config" ] && [ ! -f "$frps_config" ]; then
            echo -e "${RED}未找到任何配置文件 (frpc.toml 或 frps.toml)${NC}"
            return 1
        fi
        
        echo -e "${GREEN}请选择要备份的配置文件:${NC}"
        local config_options=()
        local index=1
        
        if [ -f "$frpc_config" ]; then
            echo "$index. frpc.toml"
            config_options[$index]="$frpc_config"
            ((index++))
        fi
        
        if [ -f "$frps_config" ]; then
            echo "$index. frps.toml"
            config_options[$index]="$frps_config"
            ((index++))
        fi
        
        echo "$index. 备份所有配置文件"
        echo "$((index+1)). 返回上一级菜单"
        
        local backup_choice
        # 修复：确保提示字符串末尾没有多余的换行符
        read -p "请选择备份操作 (1-$((index+1))): " backup_choice
        
        if [[ "$backup_choice" =~ ^[0-9]+$ ]] && [ "$backup_choice" -ge 1 ] && [ "$backup_choice" -le $((index+1)) ]; then
            if [ "$backup_choice" -eq "$((index+1))" ]; then
                echo -e "${GREEN}返回上一级菜单${NC}"
                break  # 使用 break 退出循环，返回上一级菜单
            elif [ "$backup_choice" -eq "$index" ]; then
                # 备份所有配置文件
                if [ -f "$frpc_config" ]; then
                    backup_config_file "$frpc_config"
                fi
                if [ -f "$frps_config" ]; then
                    backup_config_file "$frps_config"
                fi
                echo -e "${GREEN}所有配置文件备份完成${NC}"
                # 完成操作后不退出，显示提示并继续循环
                echo -e "${YELLOW}备份操作已完成，您可以选择继续备份或返回。${NC}"
                read -p "按 Enter 键继续..."
            else
                local selected_config="${config_options[$backup_choice]}"
                if [ -n "$selected_config" ]; then
                    backup_config_file "$selected_config"
                    # 完成操作后不退出，显示提示并继续循环
                    echo -e "${YELLOW}备份操作已完成，您可以选择继续备份或返回。${NC}"
                    read -p "按 Enter 键继续..."
                else
                    echo -e "${RED}无效的选择${NC}"
                fi
            fi
        else
            echo -e "${RED}无效的选择${NC}"
        fi
    done  # while true 循环结束
}

# 恢复配置菜单
restore_config_menu() {
    echo -e "\n${YELLOW}===== 恢复备份文件 =====${NC}"
    
    local config_choice
    read -p "请选择要恢复的配置文件类型 (1-frpc, 2-frps): " config_choice
    
    case $config_choice in
        1)
            if [ -f "frpc.toml" ]; then
                restore_backup_file "frpc.toml"
            else
                echo -e "${RED}frpc.toml 不存在${NC}"
            fi
            ;;
        2)
            if [ -f "frps.toml" ]; then
                restore_backup_file "frps.toml"
            else
                echo -e "${RED}frps.toml 不存在${NC}"
            fi
            ;;
        *)
            echo -e "${RED}无效的选择${NC}"
            ;;
    esac
}

# 配置和启动FRP服务函数
configure_and_start_frp() {
    while true; do
        read -p "你想配置和启动 FRPC 还是 FRPS? (输入 'FRPC' 或 'FRPS'): " CHOICE
        if [[ "$CHOICE" =~ ^(FRPC|frpc|FRPS|frps)$ ]]; then
            CHOICE=$(echo "$CHOICE" | tr '[:lower:]' '[:upper:]')
            break
        else
            echo -e "${RED}无效的选择，请输入 'FRPC' 或 'FRPS'。${NC}"
        fi
    done

    # 提示用户输入 token 值
    read -p "请输入 token (默认值为 '***12345678***'): " TOKEN
    if [ -z "$TOKEN" ]; then
        TOKEN="***12345678***"
    fi

    if [ "$CHOICE" = "FRPC" ]; then
        # 提示用户输入FRPC配置
        read -p "请输入服务器地址 (server_addr) [服务端的IP]: " SERVER_ADDR
        read -p "请输入服务器端口 (server_port) [默认7000]: " SERVER_PORT
        [ -z "$SERVER_PORT" ] && SERVER_PORT=7000

        read -p "请输入 FRPC 本地端口 (local_port): " LOCAL_PORT
        read -p "请输入 FRPC 远程端口 (remote_port): " REMOTE_PORT
        read -p "请输入 [http_proxy] 名称: " HTTP_PROXY_NAME

        # 更新 frpc.toml 文件
        cat > frpc.toml <<EOL
loginFailExit=false
[common]
server_addr = $SERVER_ADDR
server_port = $SERVER_PORT
log_file = "frpc.log"
log_level = "info"
log_max_days = 1
token = $TOKEN

[$HTTP_PROXY_NAME]
type = tcp
local_ip = 127.0.0.1
local_port = $LOCAL_PORT
remote_port = $REMOTE_PORT
EOL

        echo -e "${GREEN}FRPC 配置完成。${NC}"

        # 提示用户是否配置开机自启
        while true; do
            read -p "你要配置 FRPC 为开机自启吗？(yes/no): " ENABLE_FRPC_SERVICE
            if [ "$ENABLE_FRPC_SERVICE" = "yes" ] || [ "$ENABLE_FRPC_SERVICE" = "no" ]; then
                break
            else
                echo -e "${RED}无效的输入，请输入 yes 或 no。${NC}"
            fi
        done

        if [ "$ENABLE_FRPC_SERVICE" = "yes" ]; then
            SERVICE_NAME="frpc"
            INSTALL_PATH=$(pwd)

            # 写入 systemd 配置文件
            cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOL
[Unit]
Description=FRPC Service
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStart=${INSTALL_PATH}/frpc -c ${INSTALL_PATH}/frpc.toml
ExecStop=/bin/kill -TERM \$MAINPID

[Install]
WantedBy=multi-user.target
EOL

            systemctl daemon-reload
            systemctl enable ${SERVICE_NAME}
            systemctl start ${SERVICE_NAME}

            echo -e "${GREEN}FRPC 已配置为开机自启并已启动。${NC}"
            check_service_status $SERVICE_NAME
        else
            nohup ./frpc -c ./frpc.toml &
            echo -e "${GREEN}FRPC 已启动（非服务模式）。${NC}"
        fi
    
    elif [ "$CHOICE" = "FRPS" ]; then
        read -p "请输入 FRPS 监听端口 (bind_port) [默认7000]: " FRPS_PORT
        [ -z "$FRPS_PORT" ] && FRPS_PORT=7000

        read -p "请输入 FRPS 账户 (dashboard_user): " AUTH_USER
        read -p "请输入 FRPS 密码 (dashboard_pwd): " AUTH_PASS

        # 更新 frps.toml 文件
        cat > frps.toml <<EOL
[common]
bind_addr = 0.0.0.0
bind_port = $FRPS_PORT
log_file = "frps.log"
log_level = "info"
log_max_days = 1
token = $TOKEN

dashboard_user = $AUTH_USER
dashboard_pwd = $AUTH_PASS
dashboard_port = 7500
EOL

        echo -e "${GREEN}FRPS 配置完成。${NC}"

        while true; do
            read -p "你要配置 FRPS 为开机自启吗？(yes/no): " ENABLE_FRPS_SERVICE
            if [ "$ENABLE_FRPS_SERVICE" = "yes" ] || [ "$ENABLE_FRPS_SERVICE" = "no" ]; then
                break
            else
                echo -e "${RED}无效的输入，请输入 yes 或 no。${NC}"
            fi
        done

        if [ "$ENABLE_FRPS_SERVICE" = "yes" ]; then
            SERVICE_NAME="frps"
            INSTALL_PATH=$(pwd)

            cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOL
[Unit]
Description=FRPS Service
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStart=${INSTALL_PATH}/frps -c ${INSTALL_PATH}/frps.toml
ExecStop=/bin/kill -TERM \$MAINPID

[Install]
WantedBy=multi-user.target
EOL

            systemctl daemon-reload
            systemctl enable ${SERVICE_NAME}
            systemctl start ${SERVICE_NAME}

            echo -e "${GREEN}FRPS 已配置为开机自启并已启动。${NC}"
            check_service_status $SERVICE_NAME
        else
            nohup ./frps -c ./frps.toml &
            echo -e "${GREEN}FRPS 已启动（非服务模式）。${NC}"
        fi
    fi
}

# 主循环
while true; do
    show_menu
    read -p "请选择操作 (1-8): " MAIN_CHOICE
    
    case $MAIN_CHOICE in
        1)
            configure_and_start_frp
            ;;
        2)
            read -p "请输入要重启的服务名称 (frpc/frps): " SERVICE_NAME
            if [[ "$SERVICE_NAME" =~ ^(frpc|frps)$ ]]; then
                if systemctl is-active --quiet $SERVICE_NAME; then
                    restart_service $SERVICE_NAME
                else
                    echo -e "${RED}$SERVICE_NAME 服务未运行，无法重启${NC}"
                    read -p "是否要启动 $SERVICE_NAME 服务? (yes/no): " START_CHOICE
                    if [ "$START_CHOICE" = "yes" ]; then
                        systemctl start $SERVICE_NAME
                        check_service_status $SERVICE_NAME
                    fi
                fi
            else
                echo -e "${RED}无效的服务名称${NC}"
            fi
            ;;
        3)
            read -p "请输入要停止的服务名称 (frpc/frps): " SERVICE_NAME
            if [[ "$SERVICE_NAME" =~ ^(frpc|frps)$ ]]; then
                if systemctl is-active --quiet $SERVICE_NAME; then
                    stop_service $SERVICE_NAME
                else
                    echo -e "${YELLOW}$SERVICE_NAME 服务未运行${NC}"
                fi
            else
                echo -e "${RED}无效的服务名称${NC}"
            fi
            ;;
        4)
            echo -e "\n${YELLOW}===== FRP 服务状态 =====${NC}"
            check_service_status "frpc"
            check_service_status "frps"
            
            echo -e "\n${YELLOW}===== FRP 进程信息 =====${NC}"
            pgrep -f frp | while read pid; do
                echo "进程 PID: $pid, 命令: $(ps -p $pid -o cmd=)"
            done
            ;;
        5)
            echo -e "${YELLOW}===== FRP 服务卸载 =====${NC}"
            read -p "请输入要卸载的服务名称 (frpc/frps): " SERVICE_NAME
            if [[ "$SERVICE_NAME" =~ ^(frpc|frps)$ ]]; then
                uninstall_service $SERVICE_NAME
            else
                echo -e "${RED}无效的服务名称${NC}"
            fi
            ;;
        6)  # 新增的nano编辑配置文件选项
            edit_config_with_nano
            ;;
        7)  # 原来的显示系统信息
            show_system_info
            ;;
        8)  # 退出
            echo -e "${GREEN}感谢使用 FRP 管理脚本！${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选择，请重新输入${NC}"
            ;;
    esac
    
    echo
    read -p "按 Enter 键继续..."

done
