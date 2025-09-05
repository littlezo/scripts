#!/bin/bash

# 修复Intel e1000e网络适配器Hardware Unit Hang问题的脚本

# 检查是否以root用户运行
if [ "$(id -u)" != "0" ]; then
   echo "此脚本必须以root用户运行"
   exit 1
fi

# 获取e1000e网络适配器名称
ethernet_interface=$(lshw -C network | grep -A 10 "driver=e1000e" | grep "logical name" | awk '{print $3}')

if [ -z "$ethernet_interface" ]; then
    echo "未找到使用e1000e驱动的网络适配器"
    exit 1
fi

echo "找到e1000e网络适配器: $ethernet_interface"

# 方法1: 关闭TCP Segment Offload功能
echo "方法1: 关闭TCP Segment Offload功能"
ethtool -K $ethernet_interface tso off gro off gso off

# 方法2: 增加网络适配器的缓冲区大小
echo "方法2: 增加网络适配器的缓冲区大小"
ethtool -G $ethernet_interface rx 4096 tx 4096

# 方法3: 创建udev规则以在启动时应用修复
echo "方法3: 创建udev规则以在启动时应用修复"
UDEV_RULES_FILE="/etc/udev/rules.d/70-e1000e-fix.rules"
cat > $UDEV_RULES_FILE << EOF
ACTION=="add", SUBSYSTEM=="net", DRIVERS=="e1000e", RUN+="/sbin/ethtool -K %k tso off gro off gso off"
ACTION=="add", SUBSYSTEM=="net", DRIVERS=="e1000e", RUN+="/sbin/ethtool -G %k rx 4096 tx 4096"
EOF

# 方法4: 在modprobe配置中添加e1000e驱动参数
echo "方法4: 在modprobe配置中添加e1000e驱动参数"
MODPROBE_CONF_FILE="/etc/modprobe.d/e1000e.conf"
cat > $MODPROBE_CONF_FILE << EOF
options e1000e InterruptThrottleRate=30000,30000 IntMode=0,0 AdaptiveInterrupt=1,1
EOF

# 方法5: 临时重置网络适配器（立即生效）
echo "方法5: 临时重置网络适配器（立即生效）"
ifconfig $ethernet_interface down
sleep 2
ifconfig $ethernet_interface up

# 方法6: 在sysctl.conf中添加额外的网络稳定性设置
echo "方法6: 在sysctl.conf中添加额外的网络稳定性设置"
SYSCTL_CONF_FILE="/etc/sysctl.conf"

# 检查是否已存在相关设置
if ! grep -q "# e1000e stability fixes" $SYSCTL_CONF_FILE; then
    cat >> $SYSCTL_CONF_FILE << EOF

# e1000e stability fixes
net.core.netdev_max_backlog = 16384
net.ipv4.tcp_max_syn_backlog = 8192
net.core.somaxconn = 8192
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_fin_timeout = 15
EOF
fi

# 应用sysctl设置
sysctl -p

echo "e1000e网络适配器Hardware Unit Hang问题修复已完成！"
echo "请考虑重启系统以确保所有更改完全生效。"