#!/bin/bash
set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 加载环境变量（如果存在）
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
fi

# 验证必需的环境变量
required_vars=("S3_ENDPOINT" "S3_ACCESS_KEY" "S3_SECRET_KEY" "S3_BUCKET" "LOCAL_PATH")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "错误: 环境变量 $var 未设置"
        exit 1
    fi
done

# 设置默认值
S3_BUCKET_PATH="${S3_BUCKET_PATH:-/}"
# 去掉末尾的斜杠
S3_BUCKET_PATH="${S3_BUCKET_PATH%/}"
SYNC_MODE="${SYNC_MODE:-once}"
SYNC_DIRECTION="${SYNC_DIRECTION:-upload}"
MC_ALIAS="${MC_ALIAS:-s3mirror}"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# 验证同步方向
if [[ "$SYNC_DIRECTION" != "upload" && "$SYNC_DIRECTION" != "download" ]]; then
    log_error "SYNC_DIRECTION 必须是 'upload' 或 'download'"
    exit 1
fi

# 配置 mc 别名
log "配置 MinIO Client 别名..."
mc alias set "$MC_ALIAS" "$S3_ENDPOINT" "$S3_ACCESS_KEY" "$S3_SECRET_KEY" --api S3v4

# 测试连接
log "测试 S3 连接..."
if ! mc ls "$MC_ALIAS/$S3_BUCKET" >/dev/null 2>&1; then
    log_error "无法连接到 S3 存储桶: $MC_ALIAS/$S3_BUCKET"
    exit 1
fi
log "✓ S3 连接成功"

# 检查本地路径
if [ ! -d "$LOCAL_PATH" ]; then
    log_error "本地路径不存在: $LOCAL_PATH"
    exit 1
fi

# 构建 S3 目标路径
S3_TARGET="$MC_ALIAS/$S3_BUCKET$S3_BUCKET_PATH"

# 解析命令行参数
WATCH_MODE=false
for arg in "$@"; do
    case $arg in
        --watch|-w)
            WATCH_MODE=true
            ;;
        --once|-o)
            WATCH_MODE=false
            ;;
    esac
done

# 如果环境变量设置为 watch，也启用监控模式
if [ "$SYNC_MODE" = "watch" ] && [ "$WATCH_MODE" = "false" ]; then
    WATCH_MODE=true
fi

# 根据同步方向设置源和目标
if [ "$SYNC_DIRECTION" = "upload" ]; then
    SOURCE="$LOCAL_PATH/"
    TARGET="$S3_TARGET"
    DIRECTION_DESC="本地 → S3"
else
    SOURCE="$S3_TARGET"
    TARGET="$LOCAL_PATH/"
    DIRECTION_DESC="S3 → 本地"
fi

# 执行同步
if [ "$WATCH_MODE" = "true" ]; then
    log "启动持续监控同步模式 ($DIRECTION_DESC)..."
    log "源路径: $SOURCE"
    log "目标路径: $TARGET"
    log "按 Ctrl+C 停止同步"
    
    mc mirror --watch --overwrite --remove "$SOURCE" "$TARGET"
else
    log "执行单次同步 ($DIRECTION_DESC)..."
    log "源路径: $SOURCE"
    log "目标路径: $TARGET"
    
    if mc mirror --overwrite "$SOURCE" "$TARGET"; then
        log "✓ 同步完成"
    else
        log_error "同步失败"
        exit 1
    fi
fi
