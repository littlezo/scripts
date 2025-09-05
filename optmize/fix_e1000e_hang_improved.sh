# 改进版Intel e1000e网络适配器Hardware Unit Hang问题修复脚本
# 支持多种适配器检测方法和手动指定适配器

# 检查是否以root用户运行
if [ "$(id -u)" != "0" ]; then
   echo "此脚本必须以root用户运行"
   exit 1
fi

# 定义颜色常量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 打印信息函数
echo_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

echo_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 检查接口是否使用e1000e驱动
is_e1000e_interface() {
    local iface=$1
    local driver=$(readlink -f /sys/class/net/$iface/device/driver 2>/dev/null | xargs basename 2>/dev/null)
    if [ "$driver" = "e1000e" ]; then
        return 0
    else
        return 1
    fi
}

# 获取所有使用e1000e驱动的接口
get_all_e1000e_interfaces() {
    local e1000e_interfaces=()
    for iface in $(ip -o link show | grep -v lo | awk -F': ' '{print $2}'); do
        if is_e1000e_interface "$iface"; then
            e1000e_interfaces+=($iface)
        fi
    done
    echo "${e1000e_interfaces[@]}"
}

# 列出所有网络适配器并提示用户选择
list_and_select_interface() {
    # 创建临时文件来存储结果
    local result_file=$(mktemp)
    # 初始化为空
    echo "" > "$result_file"

    echo_info "系统上可用的网络适配器："
    echo "----------------------------------------"
    # 使用ip命令列出所有网络适配器
    ip -o link show | awk -F': ' '{print $2}' | grep -v lo | while read -r iface; do
        if is_e1000e_interface "$iface"; then
            echo "$iface (e1000e驱动)"
        else
            echo "$iface"
        fi
    done
    echo "----------------------------------------"

    read -p "请输入要修复的网络适配器名称 (留空使用自动检测): " user_iface

    if [ -n "$user_iface" ]; then
        # 移除可能的"(e1000e驱动)"后缀
        user_iface=$(echo "$user_iface" | sed 's/[[:space:]]*(e1000e驱动)//')
        if ip link show "$user_iface" &> /dev/null; then
            echo_success "已选择网络适配器: $user_iface"
            echo "$user_iface" > "$result_file"
        else
            echo_error "指定的网络适配器 '$user_iface' 不存在"
            exit 1
        fi
    fi

    # 从临时文件读取结果并清理
    local result=
    if [ -f "$result_file" ]; then
        result=$(cat "$result_file")
        rm -f "$result_file"
    fi
    echo "$result"
}

# 检测e1000e网络适配器
detect_e1000e_interface() {
    local interface=""

    echo_info "尝试检测使用e1000e驱动的网络适配器..."

    # 方法1: 检查/sys/class/net/中的设备驱动（更可靠的方法）
    for iface in /sys/class/net/*; do
        iface_name=$(basename "$iface")
        if [ "$iface_name" != "lo" ]; then
            if is_e1000e_interface "$iface_name"; then
                interface="$iface_name"
                break
            fi
        fi
    done

    if [ -z "$interface" ]; then
        # 方法2: 使用lshw命令 (原脚本方法)
        interface=$(lshw -C network 2>/dev/null | grep -A 10 "driver=e1000e" | grep "logical name" | awk '{print $3}')
    fi

    if [ -z "$interface" ]; then
        # 方法3: 使用lspci和grep命令
        interface=$(lspci -knn | grep -i ethernet -A 3 | grep "e1000e" -B 3 | grep "net:" | awk '{print $2}')
    fi

    if [ -z "$interface" ]; then
        # 方法4: 检查常见的Intel适配器名称模式
        possible_interfaces=$(ip -o link show | grep -v lo | awk -F': ' '{print $2}' | grep -E 'enp.*|eth.*')
        for iface in $possible_interfaces; do
            if is_e1000e_interface "$iface"; then
                interface="$iface"
                break
            fi
        done
    fi

    echo "$interface"
}

# 诊断系统网络适配器状态
diagnose_network_interfaces() {
    echo_info "正在诊断系统网络适配器状态..."
    echo "\n=== 网络适配器概览 ==="
    ip -o link show | grep -v lo

    echo "\n=== 网络适配器IP配置 ==="
    ip -o addr show | grep -v lo

    echo "\n=== 网络适配器驱动信息 ==="
    for iface in $(ip -o link show | grep -v lo | awk -F': ' '{print $2}'); do
        driver=$(readlink -f /sys/class/net/$iface/device/driver 2>/dev/null | xargs basename 2>/dev/null)
        echo "$iface: 驱动=$driver"
    done

    echo "\n=== 可能的Intel网络适配器 ==="
    lspci | grep -i ethernet | grep -i intel

    echo "\n=== 找到的e1000e适配器 ==="
    e1000e_interfaces=$(get_all_e1000e_interfaces)
    if [ -n "$e1000e_interfaces" ]; then
        for iface in $e1000e_interfaces; do
            echo "$iface: 确认使用e1000e驱动"
        done
    else
        echo "未找到使用e1000e驱动的网络适配器"
    fi
}

# 验证接口名称有效性
validate_interface() {
    local interface=$1
    if [ -z "$interface" ]; then
        echo_error "接口名称不能为空"
        return 1
    fi

    # 清理接口名，确保它不包含额外的文本
    interface=$(echo "$interface" | tr -d '\n' | tr -d '\r' | sed -e 's/^[^a-z0-9]*//' -e 's/[^a-z0-9@:/]*$//')

    if ip link show "$interface" &> /dev/null; then
        echo "$interface"
        return 0
    else
        echo_error "网络适配器 '$interface' 不存在或名称无效"
        return 1
    fi
}

# 应用e1000e修复措施
apply_e1000e_fixes() {
    local interface=$1

    # 验证接口名
    local validated_interface=$(validate_interface "$interface")
    if [ $? -ne 0 ]; then
        echo_error "无法应用修复措施：无效的接口名称"
        return 1
    fi

    interface="$validated_interface"

    # 检查接口是否使用e1000e驱动
    if ! is_e1000e_interface "$interface"; then
        echo_info "为网络适配器 $interface 应用修复措施..."
        echo_warning "网络适配器 '$interface' 不使用e1000e驱动，跳过特定于e1000e的修复措施"
        return 0
    fi

    echo_info "开始应用e1000e修复措施到适配器: $interface"

    # 检查ethtool命令是否可用
    if ! command -v ethtool &> /dev/null; then
        echo_warning "ethtool命令不可用，尝试安装..."
        if command -v apt &> /dev/null; then
            apt update && apt install -y ethtool
        elif command -v yum &> /dev/null; then
            yum install -y ethtool
        elif command -v dnf &> /dev/null; then
            dnf install -y ethtool
        else
            echo_error "无法安装ethtool，某些修复措施将无法应用"
        fi
    fi

    # 方法1: 关闭TCP Segment Offload功能
    if command -v ethtool &> /dev/null; then
        echo_info "方法1: 关闭TCP Segment Offload功能"
        ethtool -K "$interface" tso off gro off gso off
        if [ $? -eq 0 ]; then
            echo_success "已成功关闭TCP Offload功能"
        else
            echo_warning "关闭TCP Offload功能失败，可能是因为适配器不支持这些选项"
        fi

        # 方法2: 增加网络适配器的缓冲区大小
        echo_info "方法2: 增加网络适配器的缓冲区大小"
        ethtool -G "$interface" rx 4096 tx 4096
        if [ $? -eq 0 ]; then
            echo_success "已成功增加缓冲区大小"
        else
            echo_warning "增加缓冲区大小失败，可能是因为适配器有不同的缓冲区限制"
        fi
    fi

    # 方法3: 创建udev规则以在启动时应用修复
    echo_info "方法3: 创建udev规则以在启动时应用修复"
    UDEV_RULES_FILE="/etc/udev/rules.d/70-e1000e-fix.rules"
    cat > $UDEV_RULES_FILE << EOF
ACTION=="add", SUBSYSTEM=="net", RUN+="/sbin/ethtool -K %k tso off gro off gso off"
ACTION=="add", SUBSYSTEM=="net", RUN+="/sbin/ethtool -G %k rx 4096 tx 4096"
EOF
    echo_success "已创建udev规则文件: $UDEV_RULES_FILE"

    # 方法4: 在modprobe配置中添加e1000e驱动参数
    echo_info "方法4: 在modprobe配置中添加e1000e驱动参数"
    MODPROBE_CONF_FILE="/etc/modprobe.d/e1000e.conf"
    cat > $MODPROBE_CONF_FILE << EOF
options e1000e InterruptThrottleRate=30000,30000 IntMode=0,0 AdaptiveInterrupt=1,1
EOF
    echo_success "已创建modprobe配置文件: $MODPROBE_CONF_FILE"

    # 方法5: 临时重置网络适配器（立即生效）
    echo_info "方法5: 临时重置网络适配器（立即生效）"
    ifconfig "$interface" down
    sleep 2
    ifconfig "$interface" up
    if [ $? -eq 0 ]; then
        echo_success "已成功重置网络适配器"
    else
        echo_error "重置网络适配器失败，请检查网络连接"
    fi

    echo_success "e1000e网络适配器修复措施应用完成！"
    echo_warning "请考虑重启系统以确保所有更改完全生效。"
}

# 主函数
main() {
    echo "=================================================="
    echo "          Intel e1000e网络适配器修复工具           "
    echo "=================================================="

    # 首先尝试让用户手动选择适配器
    user_selected_iface=$(list_and_select_interface)

    # 如果用户没有选择，尝试自动检测
    if [ -z "$user_selected_iface" ]; then
        ethernet_interface=$(detect_e1000e_interface)
    else
        ethernet_interface="$user_selected_iface"
    fi

    # 清理变量，确保只包含有效的接口名称
    ethernet_interface=$(echo "$ethernet_interface" | tr -d '\n' | tr -d '\r' | sed -e 's/^[^a-z0-9]*//' -e 's/[^a-z0-9@:/]*$//')

    # 检查是否找到了e1000e适配器
    if [ -n "$ethernet_interface" ] && ip link show "$ethernet_interface" &> /dev/null; then
        # 验证找到的适配器确实使用e1000e驱动
        if is_e1000e_interface "$ethernet_interface"; then
            echo_success "找到使用e1000e驱动的网络适配器: $ethernet_interface"
            apply_e1000e_fixes "$ethernet_interface"
        else
            echo_warning "找到网络适配器 '$ethernet_interface'，但它不使用e1000e驱动"
            # 显示诊断信息
            diagnose_network_interfaces
        fi
    else
        echo_warning "未找到明确使用e1000e驱动的网络适配器"

        # 显示诊断信息
        diagnose_network_interfaces

        # 提供手动指定适配器的选项
        read -p "\n是否要为所有使用e1000e驱动的网络适配器应用修复措施? (y/n): " apply_all

        if [ "$apply_all" = "y" ] || [ "$apply_all" = "Y" ]; then
            # 只为使用e1000e驱动的接口应用修复
            e1000e_interfaces=$(get_all_e1000e_interfaces)
            if [ -n "$e1000e_interfaces" ]; then
                for iface in $e1000e_interfaces; do
                    echo_info "为网络适配器 $iface 应用修复措施..."
                    apply_e1000e_fixes "$iface"
                    echo "----------------------------------------"
                done
            else
                echo_error "没有找到使用e1000e驱动的网络适配器"
            fi
        else
            echo_info "您可以使用以下命令手动应用特定的修复措施:"
            echo "  1. 关闭TCP Offload: sudo ethtool -K <interface> tso off gro off gso off"
            echo "  2. 增加缓冲区: sudo ethtool -G <interface> rx 4096 tx 4096"
            echo "  3. 重启适配器: sudo ifconfig <interface> down && sudo ifconfig <interface> up"
            echo_info "根据诊断信息，我们检测到以下可能使用e1000e驱动的适配器："
            # 直接显示使用e1000e驱动的适配器
            e1000e_interfaces=$(get_all_e1000e_interfaces)
            if [ -n "$e1000e_interfaces" ]; then
                for iface in $e1000e_interfaces; do
                    echo_info "  $iface: 确认使用e1000e驱动，您可以针对此适配器手动应用修复"
                done
            else
                echo_warning "  未检测到使用e1000e驱动的网络适配器"
            fi
            echo_error "修复过程已取消"
        fi
    fi
}

# 运行主函数
main