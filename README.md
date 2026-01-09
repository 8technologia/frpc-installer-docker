# FRPC Docker Installer

Docker container cho FRPC client với tự động cấu hình và health check.

## 🚀 Cài đặt nhanh

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

### Sử dụng Docker Compose

1. Clone repo:

```bash
git clone https://github.com/8technologia/frpc-installer-docker.git
cd frpc-installer-docker
```

1. Sửa `docker-compose.yml`:

```yaml
environment:
  - SERVER_ADDR=103.166.185.156
  - SERVER_PORT=7000
  - AUTH_TOKEN=your_token
```

1. Chạy:

```bash
docker-compose up -d
```

1. Xem credentials:

```bash
docker logs frpc
```

## 📋 Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SERVER_ADDR` | ✅ | - | FRP server IP/domain |
| `SERVER_PORT` | ✅ | - | FRP server port |
| `AUTH_TOKEN` | ✅ | - | Authentication token |
| `BOX_NAME` | ❌ | Box-Docker-xxx | Container name |
| `SOCKS5_PORT` | ❌ | 51xxx | SOCKS5 remote port |
| `HTTP_PORT` | ❌ | 52xxx | HTTP remote port |
| `ADMIN_PORT` | ❌ | 53xxx | Admin API remote port |
| `PROXY_USER` | ❌ | random | Proxy username |
| `PROXY_PASS` | ❌ | random | Proxy password |
| `ADMIN_USER` | ❌ | admin | Admin username |
| `ADMIN_PASS` | ❌ | random | Admin password |
| `BANDWIDTH_LIMIT` | ❌ | 8MB | Bandwidth limit |
| `WEBHOOK_URL` | ❌ | - | Webhook URL |

## 📂 Volumes

| Path | Description |
|------|-------------|
| `/etc/frpc` | Config directory (mount to persist) |

### Persist config

```bash
docker run -d \
  -v ./config:/etc/frpc \
  ...
```

### Regenerate config on restart

```bash
# Don't mount volume, or delete config file
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

## 🏥 Health Check

Container có built-in health check:

- Interval: 30s
- Query: `http://127.0.0.1:7400/healthz`

```bash
# Check health status
docker inspect --format='{{.State.Health.Status}}' frpc
```

## 🔔 Webhook

Container gửi webhook khi start:

```json
{
  "event": "container_started",
  "message": "FRPC container started with box Box-Docker-01",
  "container_id": "abc123",
  "box_name": "Box-Docker-01"
}
```

## 🏗️ Build từ source

```bash
# Build cho platform hiện tại
docker build -t frpc:local .

# Build multi-arch
docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -t 8technologia/frpc:latest --push .
```

## 📊 So sánh với Script Installer

| Feature | Script | Docker |
|---------|--------|--------|
| Install deps | Không cần | Cần Docker |
| Systemd | Có | Không (Docker restart) |
| Health check | Cron 2 phút | Docker 30s |
| Log rotation | Script | Docker logging |
| Isolation | Không | Có |
| Multi-instance | Khó | Dễ |

## 🔧 Troubleshooting

### Token mismatch

```bash
docker logs frpc | grep -i token
```

### Port already in use

```bash
# Đặt port cố định
docker run -e SOCKS5_PORT=51999 -e HTTP_PORT=52999 -e ADMIN_PORT=53999 ...
```

### Regenerate credentials

```bash
docker stop frpc
docker rm frpc
docker run ... # credentials mới sẽ được tạo
```

## 📜 License

MIT
