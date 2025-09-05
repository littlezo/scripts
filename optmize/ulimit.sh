#!/bin/bash
# ulimit 系统资源限制优化脚本
# 基于系统硬件信息优化: Intel(R) Core(TM) i9-14900T CPU, 93GiB 内存

# 写入 limits.conf 配置文件
echo '##############################################################################
# 系统资源限制优化配置 - 基于 Intel i9-14900T + 93GiB 内存
# 优化目的: 提升系统在高并发、高性能场景下的资源使用能力
# 适用于: Swoole 应用、高性能网络服务、大数据处理等场景
##############################################################################

# 全局用户文件描述符限制
* soft nofile 1048576
* hard nofile 2097152
root soft nofile 2097152
root hard nofile 2097152

# 全局用户进程数限制
* soft nproc 1048576
* hard nproc 2097152
root soft nproc 2097152
root hard nproc 2097152

# 核心文件大小限制
* soft core unlimited
* hard core unlimited
root soft core unlimited
root hard core unlimited

# 最大锁定内存限制 (优化大内存应用)
* soft memlock unlimited
* hard memlock unlimited
root soft memlock unlimited
root hard memlock unlimited

# 最大堆栈大小限制 (优化大程序)
* soft stack 65536
* hard stack unlimited
root soft stack 65536
root hard stack unlimited

# 最大打开文件数限制 (与nofile一致)
* soft descriptors 1048576
* hard descriptors 2097152
root soft descriptors 2097152
root hard descriptors 2097152

# 进程优先级限制
* soft priority 0
* hard priority 0
root soft priority -19
root hard priority -19

# 最大 CPU 时间 (无限制)
* soft cpu unlimited
* hard cpu unlimited
root soft cpu unlimited
root hard cpu unlimited

# 最大虚拟内存 (无限制)
* soft as unlimited
* hard as unlimited
root soft as unlimited
root hard as unlimited

# 最大实时优先级
* soft rtprio 0
* hard rtprio 0
root soft rtprio 99
root hard rtprio 99

# 最大实时超时 (无限制)
* soft rttime unlimited
* hard rttime unlimited
root soft rttime unlimited
root hard rttime unlimited' | tee /etc/security/limits.conf > /dev/null

# 提示用户配置已应用
if [ $? -eq 0 ]; then
    echo "系统资源限制优化配置已成功应用到 /etc/security/limits.conf"
    echo "配置要点:
    - 文件描述符限制提升至 1048576(软) / 2097152(硬)
    - 进程数限制提升至 1048576(软) / 2097152(硬)
    - 锁定内存、堆栈、CPU时间等资源限制均优化为最佳状态
    - root用户获得更高优先级和权限"
    echo "请重启系统或重新登录以使配置生效"
else
    echo "配置应用失败，请检查权限或文件是否被锁定"
    exit 1
fi