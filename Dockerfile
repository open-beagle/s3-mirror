FROM alpine:3

# 安装必要的工具
RUN apk add --no-cache bash wget ca-certificates

# 安装 MinIO Client
RUN wget -O /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc && \
    chmod +x /usr/local/bin/mc

# 创建工作目录
WORKDIR /app

# 复制脚本
COPY scripts/sync.sh /app/sync.sh
RUN chmod +x /app/sync.sh

# 创建数据目录
RUN mkdir -p /data

# 设置环境变量默认值
ENV SYNC_MODE=watch \
    LOCAL_PATH=/data \
    MC_ALIAS=s3mirror

# 启动同步脚本
CMD ["/app/sync.sh"]
