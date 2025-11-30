# S3 Mirror - Let's Encrypt 证书同步工具

使用 MinIO Client (mc) 将 Let's Encrypt 证书同步到 S3，实现内外网证书共享。

## 使用场景

用于 Let's Encrypt 证书在互联网区域和内网区域之间同步：

- 🌐 互联网区域自动申请 Let's Encrypt 证书
- 📤 证书文件持续同步到 S3/MinIO
- 📥 内网区域从 S3 获取最新证书
- 🔄 使用 `mc mirror --watch` 实现实时同步

## 架构说明

```text
互联网区域 (acme.json)
    ↓ mc mirror --watch
  S3/MinIO 存储
    ↓ mc mirror --watch
内网区域 (acme.json)
```

## Kubernetes 部署

### 1. 修改配置

编辑 `deployments/s3-mirror.yaml`，配置以下参数：

```yaml
env:
  - name: S3_ENDPOINT
    value: "https://s3.example.com"
  - name: S3_BUCKET
    value: "your-bucket-name"
  - name: S3_BUCKET_PATH
    value: "/your-bucket"
  - name: LOCAL_PATH
    value: "/data/acme"
  - name: SYNC_DIRECTION
    value: "upload" # 互联网区域用 upload，内网区域用 download

# 配置 Secret
stringData:
  S3_ACCESS_KEY: "your_access_key"
  S3_SECRET_KEY: "your_secret_key"

# 配置 hostPath 挂载证书目录（互联网区域）
# 或使用 emptyDir（内网区域）
volumes:
  - name: data
    hostPath:
      path: /data/acme # Let's Encrypt 证书目录
      type: Directory
```

### 2. 部署到集群

```bash
kubectl apply -f deployments/s3-mirror.yaml
```

### 3. 查看运行状态

```bash
# 查看 Pod 状态
kubectl get pods -n beagle-system -l app=s3-mirror

# 查看日志
kubectl logs -n beagle-system -l app=s3-mirror -f
```

## 配置说明

### 环境变量

- `S3_ENDPOINT`: S3 服务端点
- `S3_ACCESS_KEY`: S3 访问密钥
- `S3_SECRET_KEY`: S3 密钥
- `S3_BUCKET`: 存储桶名称
- `S3_BUCKET_PATH`: 存储桶内路径（末尾斜杠会自动去除）
- `LOCAL_PATH`: 本地挂载路径（容器内）
- `SYNC_DIRECTION`: 同步方向
  - `upload`: 本地 → S3（互联网区域使用）
  - `download`: S3 → 本地（内网区域使用）

## 工作原理

容器启动后会根据 `SYNC_DIRECTION` 执行 `mc mirror --watch` 命令：

**上传模式（互联网区域）**：

- 持续监控本地目录（acme.json 等证书文件）
- 检测到文件变化时自动上传到 S3
- 使用 `--overwrite` 确保覆盖旧文件
- 使用 `--remove` 删除 S3 中已不存在的本地文件

**下载模式（内网区域）**：

- 持续监控 S3 存储桶
- 检测到 S3 文件变化时自动下载到本地
- 使用 `--overwrite` 确保覆盖旧文件
- 使用 `--remove` 删除本地已不存在于 S3 的文件

## 故障排查

### 查看同步日志

```bash
kubectl logs -n beagle-system deployment/s3-mirror
```

### 测试 S3 连接

```bash
kubectl exec -n beagle-system deployment/s3-mirror -- mc ls s3mirror/your-bucket
```

### 手动触发同步

```bash
kubectl exec -n beagle-system deployment/s3-mirror -- /app/sync.sh --once
```
