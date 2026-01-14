#!/bin/bash

# v2rayN 管理脚本
# 支持安装、卸载、更新和状态检查

SCRIPT_NAME=$(basename "$0")
V2RAYN_DEB_URL="https://github.com/2dust/v2rayN/releases/download/v7.17.0/v2rayN-linux-64.deb"
INSTALL_DIR="/opt/v2rayn"
BACKUP_DIR="$HOME/.v2rayn-backup"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查权限
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "请不要使用 root 权限运行此脚本"
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
用法: $SCRIPT_NAME [选项]

选项:
    install    安装 v2rayN
    uninstall  卸载 v2rayN
    update     更新 v2rayN
    status     检查 v2rayN 状态
    help      显示此帮助信息

示例:
    $SCRIPT_NAME install    # 安装 v2rayN
    $SCRIPT_NAME status     # 检查安装状态
    $SCRIPT_NAME update     # 更新到最新版本
    $SCRIPT_NAME uninstall  # 卸载 v2rayN
EOF
}

# 检查系统依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    local missing_deps=()
    
    for dep in wget curl dpkg sudo; do
        if ! command -v $dep &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warning "缺少以下依赖: ${missing_deps[*]}"
        log_info "尝试安装依赖..."
        sudo apt update
        sudo apt install -y "${missing_deps[@]}"
    fi
}

# 下载 v2rayN
download_v2rayn() {
    local download_url="$1"
    local output_file="$2"
    
    log_info "下载 v2rayN..."
    
    if ! wget -O "$output_file" "$download_url"; then
        log_error "下载失败！请检查网络连接"
        return 1
    fi
    
    if [[ ! -f "$output_file" ]]; then
        log_error "下载文件不存在"
        return 1
    fi
    
    log_success "下载完成: $output_file"
    return 0
}

# 安装 v2rayN
install_v2rayn() {
    log_info "开始安装 v2rayN..."
    
    # 创建临时目录
    local temp_dir=$(mktemp -d)
    local deb_file="$temp_dir/v2rayN.deb"
    
    # 下载 DEB 包
    if ! download_v2rayn "$V2RAYN_DEB_URL" "$deb_file"; then
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 安装依赖
    log_info "安装系统依赖..."
    sudo apt update
    sudo apt install -y libappindicator3-1 libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils
    
    # 安装 DEB 包
    log_info "安装 v2rayN..."
    if ! sudo dpkg -i "$deb_file"; then
        log_warning "安装过程中出现依赖问题，尝试修复..."
        sudo apt install -f -y
    fi
    
    # 清理临时文件
    rm -rf "$temp_dir"
    
    # 验证安装
    if dpkg -l | grep -q v2rayn; then
        log_success "v2rayN 安装成功！"
        log_info "您可以通过以下方式启动:"
        echo "    - 应用程序菜单搜索 'v2rayN'"
        echo "    - 终端运行: v2rayN"
    else
        log_error "安装验证失败"
        return 1
    fi
}

# 卸载 v2rayN
uninstall_v2rayn() {
    log_info "开始卸载 v2rayN..."
    
    # 检查是否已安装
    if ! dpkg -l | grep -q v2rayn; then
        log_warning "v2rayN 未安装"
        return 0
    fi
    
    # 备份配置文件
    if [[ -d "$HOME/.config/v2rayN" ]]; then
        log_info "备份配置文件..."
        mkdir -p "$BACKUP_DIR"
        cp -r "$HOME/.config/v2rayN" "$BACKUP_DIR/"
        log_success "配置文件已备份到: $BACKUP_DIR"
    fi
    
    # 卸载包
    if sudo dpkg -r v2rayn; then
        log_success "v2rayN 卸载成功"
        
        # 询问是否删除配置
        read -p "是否删除配置文件? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$HOME/.config/v2rayN"
            log_success "配置文件已删除"
        fi
    else
        log_error "卸载失败"
        return 1
    fi
}

# 更新 v2rayN
update_v2rayn() {
    log_info "检查更新..."
    
    # 这里可以添加版本检查逻辑
    # 目前简单重新安装最新版本
    
    uninstall_v2rayn
    install_v2rayn
}

# 检查状态
check_status() {
    log_info "检查 v2rayN 状态..."
    
    if dpkg -l | grep -q v2rayn; then
        local version=$(dpkg -l | grep v2rayn | awk '{print $3}')
        log_success "v2rayN 已安装 - 版本: $version"
        
        # 检查是否在运行
        if pgrep -x "v2rayN" > /dev/null; then
            log_success "v2rayN 正在运行"
        else
            log_info "v2rayN 未运行"
        fi
    else
        log_warning "v2rayN 未安装"
    fi
    
    # 检查配置文件
    if [[ -d "$HOME/.config/v2rayN" ]]; then
        log_info "配置文件位置: $HOME/.config/v2rayN"
    fi
}

# 主函数
main() {
    local command=$1
    
    case $command in
        "install")
            check_root
            check_dependencies
            install_v2rayn
            ;;
        "uninstall")
            check_root
            uninstall_v2rayn
            ;;
        "update")
            check_root
            check_dependencies
            update_v2rayn
            ;;
        "status")
            check_status
            ;;
        "help"|"")
            show_help
            ;;
        *)
            log_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi