#!/bin/bash

# 系统sysctl配置备份脚本

# 检查是否以root用户运行
if [ "$(id -u)" != "0" ]; then
   echo "此脚本必须以root用户运行"
   exit 1
fi

# 定义配置文件路径
ORIGINAL_SYSCTL="/etc/sysctl.conf"
BACKUP_DIR="/data/project/muke-interface/scripts/sys/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/sysctl.conf.backup.${TIMESTAMP}"

# 创建备份目录
mkdir -p "${BACKUP_DIR}"

# 备份当前sysctl配置
if [ -f "${ORIGINAL_SYSCTL}" ]; then
    cp -v "${ORIGINAL_SYSCTL}" "${BACKUP_FILE}"
    echo "sysctl配置已备份到: ${BACKUP_FILE}"
else
    echo "警告: 未找到原始sysctl配置文件 ${ORIGINAL_SYSCTL}"
    touch "${BACKUP_FILE}"
    echo "创建了空备份文件: ${BACKUP_FILE}"
fi

# 显示最近的几次备份
echo "\n最近的备份文件："
ls -lht "${BACKUP_DIR}"/sysctl.conf.backup.* | head -5

# 显示备份占用的磁盘空间
echo "\n备份目录占用空间："
du -sh "${BACKUP_DIR}"

# 提示用户
cat << EOF

备份完成！

注意事项：
1. 建议定期清理过时的备份文件，以节省磁盘空间
2. 在应用新的sysctl配置前，请确保已创建备份
3. 如需恢复备份，可以使用以下命令：
   cp -v ${BACKUP_FILE} ${ORIGINAL_SYSCTL}
   sysctl -p

EOF