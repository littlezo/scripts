#!/bin/bash

# 优化 .bash_history 脚本
# 此脚本提供多种功能来管理和增强 bash 命令历史记录

# 配置变量
HISTORY_FILE="$HOME/.bash_history"
BACKUP_DIR="$HOME/.bash_history_backups"
MAX_HISTORY_SIZE=10000000  # 最大历史记录条数（1千万条）
MAX_HISTORY_FILE_SIZE=10485760  # 10MB，最大历史文件大小（以字节为单位）
DAYS_TO_KEEP=1095  # 保留多少天的历史记录（3年约1095天）

# 检查并创建备份目录
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    echo "创建备份目录: $BACKUP_DIR"
fi

# 备份当前的 .bash_history 文件
backup_history() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    cp "$HISTORY_FILE" "$BACKUP_DIR/bash_history_$timestamp.bak"
    echo "已备份当前历史文件到: $BACKUP_DIR/bash_history_$timestamp.bak"
}

# 清理重复的命令
clean_duplicates() {
    echo "正在清理重复的命令..."
    # 使用 awk 去除重复行，同时保留最后一次出现的命令
    awk '!a[$0]++' "$HISTORY_FILE" > "$HISTORY_FILE.tmp"
    mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    echo "重复命令清理完成"
}

# 限制历史记录大小
truncate_history() {
    echo "正在限制历史记录大小..."
    # 只保留最后 MAX_HISTORY_SIZE 行
    if [ -f "$HISTORY_FILE" ]; then
        local lines=$(wc -l < "$HISTORY_FILE")
        if [ $lines -gt $MAX_HISTORY_SIZE ]; then
            tail -n $MAX_HISTORY_SIZE "$HISTORY_FILE" > "$HISTORY_FILE.tmp"
            mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
            echo "已将历史记录限制为 $MAX_HISTORY_SIZE 行"
        fi
    fi
}

# 设置 bash 历史相关的环境变量
set_history_settings() {
    echo "正在配置 bash 历史环境变量..."
    cat << 'EOF' >> "$HOME/.bashrc"

# === 优化 bash 历史设置 ===
# 控制历史记录大小
export HISTSIZE=10000000
# 控制文件大小
export HISTFILESIZE=10000000
# 忽略重复命令
export HISTCONTROL=ignoredups:ignorespace
# 忽略特定命令
export HISTIGNORE="ls:ls -la:pwd:cd:exit:clear"
# 记录时间戳
export HISTTIMEFORMAT="%F %T "
# 实时追加历史记录
export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
# === 优化 bash 历史设置结束 ===
EOF
    echo "已将历史设置添加到 $HOME/.bashrc"
    echo "请运行 'source ~/.bashrc' 使设置生效"
}

# 显示帮助信息
show_help() {
    echo "优化 .bash_history 脚本"
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -b, --backup         备份当前历史文件"
    echo "  -c, --clean          清理重复的历史命令"
    echo "  -t, --truncate       限制历史记录大小"
    echo "  -s, --settings       设置 bash 历史相关环境变量"
    echo "  -a, --all            执行所有优化操作"
    echo "  -h, --help           显示此帮助信息"
}

# 主函数
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            -b|--backup)
                backup_history
                ;;
            -c|--clean)
                clean_duplicates
                ;;
            -t|--truncate)
                truncate_history
                ;;
            -s|--settings)
                set_history_settings
                ;;
            -a|--all)
                backup_history
                clean_duplicates
                truncate_history
                set_history_settings
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# 运行主函数
main "$@"