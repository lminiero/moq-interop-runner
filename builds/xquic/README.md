# xquic MoQ Interop Docker Images

xquic MoQ 互通测试的 Docker 镜像构建与推送指南。

## 镜像列表

| 镜像 | 用途 | GHCR 地址 |
|------|------|-----------|
| xquic-moq-client | interop 测试客户端 | `ghcr.io/sy0307/xquic-moq-client:latest` |
| xquic-moq-relay | MoQ relay 服务 | `ghcr.io/sy0307/xquic-moq-relay:latest` |

当前 GHCR 上的镜像为 **arm64** 架构。moq-interop-runner CI 需要 **amd64** 镜像，
请在 x86_64 Linux 机器上按以下步骤构建并推送。

## 在 amd64 Linux 机器上构建

### 前置条件

- Docker 已安装
- 已 clone xquic 源码（含 `third_party/babassl` 和 MoQ interop 改动）
- 已 clone moq-interop-runner 源码
- GitHub Personal Access Token（Classic，需要 `write:packages` 权限）

### 构建步骤

```bash
# 1. 进入 moq-interop-runner 目录
cd /path/to/moq-interop-runner

# 2. 构建 client 和 relay 镜像（使用本地 xquic 源码）
bash builds/xquic/build.sh --local /path/to/xquic --target client
bash builds/xquic/build.sh --local /path/to/xquic --target relay

# 3. 验证镜像
docker images | grep xquic-moq

# 4. 快速功能测试（client 对远程 relay）
docker run --rm \
  -e RELAY_URL=moqt://draft-14.cloudflare.mediaoverquic.com:443 \
  -e TESTCASE=setup-only \
  -e VERBOSE=1 \
  xquic-moq-client:latest
```

### 推送到 GHCR

```bash
# 1. 登录 GHCR
echo "$GITHUB_TOKEN" | docker login ghcr.io -u <github-username> --password-stdin

# 2. 打 tag
docker tag xquic-moq-client:latest ghcr.io/<github-username>/xquic-moq-client:latest
docker tag xquic-moq-relay:latest ghcr.io/<github-username>/xquic-moq-relay:latest

# 3. 推送
docker push ghcr.io/<github-username>/xquic-moq-client:latest
docker push ghcr.io/<github-username>/xquic-moq-relay:latest
```

推送完成后需要在 GitHub Packages 页面将镜像可见性设为 **Public**，
否则 moq-interop-runner CI 无法拉取。

### 多架构镜像（可选）

如果需要同时支持 arm64 和 amd64，可以使用 `docker buildx` 构建多架构 manifest：

```bash
# 确保 buildx 可用
docker buildx create --name multiarch --use
docker buildx inspect --bootstrap

# 构建并推送多架构镜像（以 client 为例）
cd /path/to/xquic
cp /path/to/moq-interop-runner/builds/xquic/entrypoint-client.sh .
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -f /path/to/moq-interop-runner/builds/xquic/Dockerfile.client \
  -t ghcr.io/<github-username>/xquic-moq-client:latest \
  --push .
rm entrypoint-client.sh

# relay 同理
cp /path/to/moq-interop-runner/builds/xquic/entrypoint-relay.sh .
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -f /path/to/moq-interop-runner/builds/xquic/Dockerfile.relay \
  -t ghcr.io/<github-username>/xquic-moq-relay:latest \
  --push .
rm entrypoint-relay.sh
```

## 更新 implementations.json

推送镜像后，需要更新 `implementations.json` 中 xquic 条目的 `docker.image` 字段，
使其指向正确的 GHCR 地址。如果切换到 alibaba 组织的命名空间，则改为：

```json
"image": "ghcr.io/alibaba/xquic-moq-client:latest"
```

## 支持的测试用例

| 测试用例 | 说明 |
|----------|------|
| setup-only | CLIENT_SETUP / SERVER_SETUP 握手 |
| announce-only | PUBLISH_NAMESPACE + 等待 OK |
| subscribe-error | 订阅不存在的 namespace，期望 SUBSCRIBE_ERROR |
| publish-namespace-done | PUBLISH_NAMESPACE + PUBLISH_NAMESPACE_DONE |
| announce-subscribe | 发布者 ANNOUNCE 后订阅者 SUBSCRIBE，期望 SUBSCRIBE_OK |
| subscribe-before-announce | 订阅者先 SUBSCRIBE，发布者后 ANNOUNCE，期望 SUBSCRIBE_OK |

## 环境变量

| 变量 | 说明 | 示例 |
|------|------|------|
| RELAY_URL | relay 地址（必需） | `moqt://host:4443` |
| TESTCASE | 测试用例名（可选，不设则跑全部） | `setup-only` |
| TLS_DISABLE_VERIFY | 跳过证书验证 | `1` |
| VERBOSE | 详细日志 | `1` |
