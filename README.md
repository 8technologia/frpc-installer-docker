# FRPC Docker Installer

Docker container cho FRPC client với tự động cấu hình và health check.

## 🚀 Cài đặt nhanh

### Sử dụng Docker Compose (khuyến nghị)

1. Clone repo:

```bash
git clone https://github.com/8technologia/frpc-installer-docker.git
cd frpc-installer-docker
```

1. Tạo file `.env` từ template:

```bash
cp .env.example .env
```

1. Sửa file `.env`:

```env
SERVER_ADDR=103.166.185.156
SERVER_PORT=7000
AUTH_TOKEN=your_token_here
BOX_NAME=Box-HaNoi-01
```

1. Chạy:

```bash
docker-compose up -d
```

1. Xem credentials:

```bash
docker logs frpc-Box-HaNoi-01
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
| `AUTH_TOKEN` | Authentication token (phải khớp với server) |
| `BOX_NAME` | Tên box (ví dụ: Box-HaNoi-01) |

### Optional (tùy chọn)

| Variable | Default | Description |
|----------|---------|-------------|
| `SOCKS5_PORT` | 51xxx | SOCKS5 remote port |
| `HTTP_PORT` | 52xxx | HTTP remote port |
| `ADMIN_PORT` | 53xxx | Admin API remote port |
| `PROXY_USER` | random | Proxy username |
| `PROXY_PASS` | random | Proxy password |
| `ADMIN_USER` | admin | Admin username |
| `ADMIN_PASS` | random | Admin password |
| `BANDWIDTH_LIMIT` | 8MB | Bandwidth limit |
| `WEBHOOK_URL` | - | Webhook URL |

## 📂 File .env

```env
# Required - BẮT BUỘC phải set
SERVER_ADDR=103.166.185.156
SERVER_PORT=7000
AUTH_TOKEN=your_secret_token
BOX_NAME=Box-HaNoi-01

# Optional - Tự động tạo nếu không set
# SOCKS5_PORT=51234
# HTTP_PORT=52234
# ADMIN_PORT=53234
# PROXY_USER=myuser
# PROXY_PASS=mypass
# BANDWIDTH_LIMIT=8MB

# Webhook (optional)
# WEBHOOK_URL=https://webhook.site/xxx
```

## 📂 Volumes

| Path | Description |
|------|-------------|
| `/etc/frpc` | Config directory (mount để persist) |

### Persist config

```bash
docker run -d \
  -v ./config:/etc/frpc \
  ...
```

### Regenerate config

```bash
docker exec frpc rm /etc/frpc/frpc.toml
docker restart frpc
```

## 🖥️ Commands

```bash
# View logs
docker logs -f frpc-Box-HaNoi-01

# Restart
docker restart frpc-Box-HaNoi-01

# Stop
docker stop frpc-Box-HaNoi-01

# View config
docker exec frpc-Box-HaNoi-01 cat /etc/frpc/frpc.toml

# Shell access
docker exec -it frpc-Box-HaNoi-01 sh
```

## 🏥 Health Check

Container có built-in health check:

- Interval: 30s
- Endpoint: `http://127.0.0.1:7400/healthz`

```bash
# Check health status
docker inspect --format='{{.State.Health.Status}}' frpc-Box-HaNoi-01
```

## 🔔 Webhook

Container gửi webhook khi start:

```json
{
  "event": "container_started",
  "message": "FRPC container started with box Box-HaNoi-01",
  "container_id": "abc123",
  "box_name": "Box-HaNoi-01"
}
```

## 🏗️ Build từ source

```bash
# Build cho platform hiện tại
docker build -t frpc:local .

# Build multi-arch
docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -t 8technologia/frpc:latest --push .
```

## 🔧 Troubleshooting

### Missing environment variables

```
ERROR: Required environment variables not set

Required:
  SERVER_ADDR  - FRP server IP/domain
  SERVER_PORT  - FRP server port
  AUTH_TOKEN   - Authentication token
  BOX_NAME     - Box name
```

→ Đảm bảo đã set đủ 4 biến required trong `.env` hoặc `-e`

### Token mismatch

```bash
docker logs frpc-Box-01 | grep -i token
```

### Port already in use

```bash
# Đặt port cố định trong .env
SOCKS5_PORT=51999
HTTP_PORT=52999
ADMIN_PORT=53999
```

## 📜 License

MIT
