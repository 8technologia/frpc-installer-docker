# FRPC Docker Installer

Docker container cho FRPC client với tự động cấu hình, health check và webhook notifications.

## ✅ Tính năng

- **Zero-config**: Tự động tạo config với random ports và credentials
- **Multi-arch**: Hỗ trợ amd64, arm64, arm
- **Health Check**: Docker built-in health check
- **Webhook**: 3 events (started, ready, error)
- **Auto-restart**: Docker restart policy

## 🚀 Cài đặt nhanh

### Sử dụng Docker Compose (khuyến nghị)

1. Clone repo:

```bash
git clone https://github.com/8technologia/frpc-installer-docker.git
cd frpc-installer-docker
```

1. Tạo file `.env`:

```bash
cp .env.example .env
nano .env
```

1. Điền thông tin:

```env
SERVER_ADDR=103.166.185.156
SERVER_PORT=7000
AUTH_TOKEN=your_token_here

# Optional
BOX_NAME=Box-HaNoi-01
WEBHOOK_URL=https://webhook.site/xxx
```

1. Chạy:

```bash
docker-compose up -d
docker logs frpc
```

### Sử dụng Docker Run

```bash
docker run -d \
  --name frpc \
  --restart unless-stopped \
  -e SERVER_ADDR=103.166.185.156 \
  -e SERVER_PORT=7000 \
  -e AUTH_TOKEN=your_token \
  -e BOX_NAME=Box-Docker-01 \
  -e WEBHOOK_URL=https://webhook.site/xxx \
  8technologia/frpc:latest
```

## 📋 Environment Variables

### Required (bắt buộc)

| Variable | Description |
|----------|-------------|
| `SERVER_ADDR` | FRP server IP/domain |
| `SERVER_PORT` | FRP server port |
| `AUTH_TOKEN` | Authentication token |

### Optional (tùy chọn)

| Variable | Default | Description |
|----------|---------|-------------|
| `BOX_NAME` | Box-Docker-xxx | Tên box |
| `SOCKS5_PORT` | 51xxx | SOCKS5 remote port |
| `HTTP_PORT` | 52xxx | HTTP remote port |
| `ADMIN_PORT` | 53xxx | Admin API remote port |
| `PROXY_USER` | random | Proxy username |
| `PROXY_PASS` | random | Proxy password |
| `ADMIN_USER` | admin | Admin username |
| `ADMIN_PASS` | random | Admin password |
| `BANDWIDTH_LIMIT` | 8MB | Bandwidth limit |
| `WEBHOOK_URL` | - | Webhook URL |

## 🔔 Webhook Events

| Event | Khi nào | Có logs |
|-------|---------|---------|
| `container_started` | Container khởi động, config tạo xong | ❌ |
| `container_ready` | frpc connect thành công, proxies hoạt động | ❌ |
| `container_error` | Lỗi token/port/connection | ✅ |

### Luồng webhook

```
Container start
  ├─ Tạo config
  ├─ Gửi webhook: container_started
  ├─ Start frpc
  ├─ Đợi 8 giây
  ├─ Check proxies
  │   ├─ OK? → Gửi webhook: container_ready
  │   └─ Fail? → Gửi webhook: container_error (có logs)
  └─ Container tiếp tục chạy
```

### Ví dụ webhook payload

**container_started:**

```json
{
  "event": "container_started",
  "message": "FRPC container started with box Box-Docker-01",
  "box_name": "Box-Docker-01",
  "public_ip": "123.45.67.89",
  "container_id": "abc123"
}
```

**container_ready:**

```json
{
  "event": "container_ready",
  "message": "FRPC proxies are running for box Box-Docker-01",
  "box_name": "Box-Docker-01"
}
```

**container_error:**

```json
{
  "event": "container_error",
  "message": "Token mismatch - check AUTH_TOKEN|[frpc logs...]",
  "box_name": "Box-Docker-01"
}
```

## 🏥 Health Check

| Config | Value |
|--------|-------|
| Interval | 30 giây |
| Endpoint | `http://127.0.0.1:7400/healthz` |
| Start period | 10 giây |
| Retries | 3 |

```bash
# Check health status
docker inspect --format='{{.State.Health.Status}}' frpc
```

## 📂 Volumes

| Path | Description |
|------|-------------|
| `/etc/frpc` | Config directory |

```bash
# Mount để persist config
docker run -v ./config:/etc/frpc ...

# Regenerate config
docker exec frpc rm /etc/frpc/frpc.toml
docker restart frpc
```

## 🖥️ Commands

```bash
# View logs
docker logs -f frpc

# Restart
docker restart frpc

# Stop
docker stop frpc

# View config
docker exec frpc cat /etc/frpc/frpc.toml

# Shell access
docker exec -it frpc sh
```

## 🔄 Cập nhật phiên bản mới

### Build Local từ GitHub (khuyến nghị)

```bash
cd frpc-installer-docker

# Pull code mới từ GitHub
git pull

# Build lại image
docker-compose build --no-cache

# Restart với image mới (giữ config)
docker-compose up -d

# Xem logs
docker logs frpc
```

### Cập nhật và regenerate config mới

```bash
# Xóa config cũ để tạo credentials mới
docker exec frpc rm /etc/frpc/frpc.toml

# Restart
docker-compose up -d --force-recreate

# Xem credentials mới
docker logs frpc
```

## 🏗️ Build từ source

```bash
# Build local
docker build -t frpc:local .

# Build multi-arch và push
docker buildx build \
  --platform linux/amd64,linux/arm64,linux/arm/v7 \
  -t 8technologia/frpc:latest \
  --push .
```

## 📊 So sánh với Script Installer

| Feature | Script (v3.2) | Docker |
|---------|---------------|--------|
| Install | `curl \| bash` | `docker-compose up` |
| Dependencies | Không | Docker |
| Health check | Cron 2 phút | Docker 30s |
| Webhook events | 6 | 3 |
| Auto-restart | Via health check | Docker policy |
| Log rotation | Script | Docker logging |
| Best for | Dedicated boxes | Shared servers |

## 🔧 Troubleshooting

### Missing environment variables

```
ERROR: Required environment variables not set
```

→ Kiểm tra đã set `SERVER_ADDR`, `SERVER_PORT`, `AUTH_TOKEN` trong `.env`

### Token mismatch

```bash
docker logs frpc | grep -i token
```

→ Kiểm tra `AUTH_TOKEN` khớp với server

### Port already in use

```bash
# Đặt port cố định trong .env
SOCKS5_PORT=51999
HTTP_PORT=52999
ADMIN_PORT=53999
```

### Container unhealthy

```bash
docker inspect --format='{{.State.Health.Status}}' frpc
docker logs frpc
```

## 📜 License

MIT
