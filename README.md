# FRPC Docker Installer

Docker container cho FRPC client với tự động cấu hình, health check và webhook notifications.

## ✅ Tính năng

- **Zero-config**: Tự động tạo config với random ports và credentials
- **Multi-arch**: Hỗ trợ amd64, arm64, arm
- **Health Check**: Docker built-in health check
- **Webhook**: Gửi thông báo khi proxy hoạt động hoặc có lỗi
- **Auto-restart**: Docker restart policy
- **Quick Copy**: Format `IP:PORT:USER:PASS` để copy nhanh

## 🚀 Cài đặt

### 1. Clone repo

```bash
git clone https://github.com/8technologia/frpc-installer-docker.git
cd frpc-installer-docker
```

### 2. Tạo file `.env`

```bash
cp .env.example .env
nano .env
```

### 3. Điền thông tin

```env
SERVER_ADDR=103.166.185.156
SERVER_PORT=7000
AUTH_TOKEN=your_token_here

# Optional
BOX_NAME=Box-HaNoi-01
WEBHOOK_URL=https://webhook.site/xxx
```

### 4. Build và chạy

```bash
docker-compose build
docker-compose up -d
docker logs frpc
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
| `container_ready` | Proxies hoạt động | ❌ |
| `container_error` | Có lỗi (token/port) | ✅ |

### Ví dụ webhook payload

```json
{
  "event": "container_ready",
  "message": "FRPC proxies are running for box Box-Docker-01",
  "timestamp": "2026-01-10T00:42:56+00:00",
  "hostname": "e9edeeb610a2",
  "box_name": "Box-Docker-01",
  "public_ip": "210.16.120.234",
  "container_id": "e9edeeb610a2",
  "server": "103.166.185.156:7000",
  "proxies": {
    "socks5": {
      "port": 51284,
      "address": "103.166.185.156:51284",
      "username": "abc123",
      "password": "xyz789",
      "quick": "103.166.185.156:51284:abc123:xyz789"
    },
    "http": {
      "port": 52284,
      "address": "103.166.185.156:52284",
      "username": "abc123",
      "password": "xyz789",
      "quick": "103.166.185.156:52284:abc123:xyz789"
    },
    "admin_api": {
      "port": 53284,
      "address": "103.166.185.156:53284",
      "username": "admin",
      "password": "adminpass"
    }
  }
}
```

## 🖥️ Commands

```bash
# Xem logs
docker logs -f frpc

# Restart
docker restart frpc

# Stop
docker stop frpc

# Xem config
docker exec frpc cat /etc/frpc/frpc.toml

# Shell access
docker exec -it frpc sh
```

## 🔄 Cập nhật phiên bản mới

```bash
cd frpc-installer-docker

# Pull code mới từ GitHub
git pull

# Build lại
docker-compose build --no-cache

# Restart (giữ config)
docker-compose up -d
```

## 🗑️ Xóa hết và tạo credentials mới

```bash
cd frpc-installer-docker

# Down container
docker-compose down

# Xóa config
rm -rf ./config/*

# Build và chạy lại
docker-compose build --no-cache
docker-compose up -d

# Xem credentials mới
docker logs frpc
```

## 🏥 Health Check

| Config | Value |
|--------|-------|
| Interval | 30 giây |
| Endpoint | `http://127.0.0.1:7400/healthz` |
| Start period | 10 giây |
| Retries | 3 |

```bash
docker inspect --format='{{.State.Health.Status}}' frpc
```

## 📂 Cấu trúc

```
frpc-installer-docker/
├── Dockerfile
├── docker-compose.yml
├── entrypoint.sh
├── .env.example
├── .env              # Bạn tạo
└── config/           # Mount volume
    └── frpc.toml     # Auto-generated
```

## ⚙️ Yêu cầu FRP Server

```toml
# frps.toml
bindPort = 7000

auth.method = "token"
auth.token = "your_secret_token"

allowPorts = [
  { start = 51001, end = 53999 }
]
```

## 🔧 Troubleshooting

### Missing environment variables

```
ERROR: Required environment variables not set
```

→ Kiểm tra `.env` đã set `SERVER_ADDR`, `SERVER_PORT`, `AUTH_TOKEN`

### Token mismatch

```bash
docker logs frpc | grep -i token
```

→ Kiểm tra `AUTH_TOKEN` khớp với `auth.token` trong frps.toml

### Port not allowed

→ Thêm vào frps.toml:

```toml
allowPorts = [{ start = 51001, end = 53999 }]
```

### Authentication required khi dùng proxy

→ Xóa config và tạo lại:

```bash
rm -rf ./config/*
docker-compose up -d --force-recreate
docker logs frpc
```

## 📜 License

MIT
