# FRPC Docker Auto-Installer

Docker container cho FRPC client với:

- ✅ Auto-generate config, credentials
- ✅ Admin API với auto-save (thay đổi config không cần restart)
- ✅ Webhook notifications
- ✅ Persist config qua volume

## Quick Start

```bash
git clone https://github.com/8technologia/frpc-installer-docker.git
cd frpc-installer-docker
cp .env.example .env
# Edit .env với SERVER_ADDR, SERVER_PORT, AUTH_TOKEN

docker-compose up -d
docker logs frpc
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `SERVER_ADDR` | ✅ | FRP server IP/domain |
| `SERVER_PORT` | ✅ | FRP server port |
| `AUTH_TOKEN` | ✅ | Authentication token |
| `BOX_NAME` | ❌ | Box name (auto-generated) |
| `SOCKS5_PORT` | ❌ | SOCKS5 port (auto: 51xxx) |
| `HTTP_PORT` | ❌ | HTTP proxy port (auto: 52xxx) |
| `ADMIN_PORT` | ❌ | Admin API port (auto: 53xxx) |
| `PROXY_USER` | ❌ | Proxy username (auto-generated) |
| `PROXY_PASS` | ❌ | Proxy password (auto-generated) |
| `ADMIN_USER` | ❌ | Admin username (default: admin) |
| `ADMIN_PASS` | ❌ | Admin password (auto-generated) |
| `BANDWIDTH_LIMIT` | ❌ | Bandwidth limit (default: 8MB) |
| `WEBHOOK_URL` | ❌ | Webhook endpoint |

## Admin API

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/status` | Lấy status các proxy |
| GET | `/api/config` | Lấy config hiện tại |
| PUT | `/api/config` | **Update + Reload + Save ngay** |

### Đổi config (real-time, không cần restart)

```bash
curl -X PUT -u "admin:PASSWORD" \
  -H "Content-Type: text/plain" \
  -d 'NEW_CONFIG_CONTENT' \
  http://SERVER:ADMIN_PORT/api/config
```

**Response:**

```json
{"status":"updated","saved":true}
```

### Đổi admin password

Config mới với password mới → áp dụng ngay:

```toml
webServer.user = "newadmin"
webServer.password = "newpassword"
```

## Webhook Events

### container_ready

Gửi khi container khởi động thành công:

```json
{
  "event": "container_ready",
  "message": "FRPC proxies are running for box Box-Docker-xxx",
  "timestamp": "2026-01-10T02:00:00+00:00",
  "hostname": "container_id",
  "box_name": "Box-Docker-xxx",
  "public_ip": "xxx.xxx.xxx.xxx",
  "server": "server:port",
  "proxies": {
    "socks5": {
      "port": 51xxx,
      "address": "server:51xxx",
      "username": "xxx",
      "password": "xxx",
      "quick": "server:port:user:pass"
    },
    "http": {
      "port": 52xxx,
      "address": "server:52xxx",
      "username": "xxx",
      "password": "xxx",
      "quick": "server:port:user:pass"
    },
    "admin_api": {
      "port": 53xxx,
      "address": "server:53xxx",
      "username": "admin",
      "password": "xxx",
      "auto_save": true
    }
  }
}
```

### container_error

Gửi khi có lỗi kết nối.

## Commands

### Start

```bash
docker-compose up -d
```

### View logs

```bash
docker logs frpc
docker logs -f frpc  # follow
```

### Restart

```bash
docker restart frpc
```

### Stop

```bash
docker-compose down
```

### Reset config (regenerate credentials)

```bash
rm -rf ./config/*
docker-compose up -d
```

## Update

```bash
cd frpc-installer-docker
git pull
docker-compose build --no-cache
docker-compose up -d
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ External Client                                         │
│   curl -u admin:pass http://server:53xxx/api/config    │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌────────────────────┴────────────────────────────────────┐
│ Python Config Proxy (port 7400)                         │
│ - Verify external auth                                  │
│ - Forward to frpc with internal auth                    │
│ - Auto-save after PUT /api/config                       │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌────────────────────┴────────────────────────────────────┐
│ FRPC Admin API (port 7402, internal only)              │
│ - PUT /api/config → update memory                       │
│ - GET /api/reload → apply config                        │
└─────────────────────────────────────────────────────────┘
```

## Directory Structure

```
frpc-installer-docker/
├── docker-compose.yml
├── Dockerfile
├── entrypoint.sh
├── config_proxy.py      # Python HTTP proxy với auth
├── .env.example
├── .gitignore
├── README.md
└── config/              # Volume mount, DO NOT commit
    └── frpc.toml
```

## Troubleshooting

### Container không kết nối được

1. Check logs: `docker logs frpc`
2. Verify AUTH_TOKEN đúng
3. Check firewall trên FRP server

### Admin API không hoạt động

1. Đợi container ready (webhook `container_ready`)
2. Verify credentials trong webhook
3. Test: `curl -u admin:PASS http://server:port/api/status`

### Config không persist

1. Check volume mount: `./config:/etc/frpc`
2. Check thư mục `config/` có file `frpc.toml`

## Version History

- **v1.0** - Initial Docker version
- **v1.1** - Added webhook support
- **v1.2** - Added Admin API with auto-save
- **v1.3** - Python HTTP proxy for proper auth
- **v1.4** - Separate HTTP/SOCKS5 passwords in webhook

## License

MIT
