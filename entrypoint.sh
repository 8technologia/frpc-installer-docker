#!/bin/bash
set -e

CONFIG_FILE="/etc/frpc/frpc.toml"
LOG_FILE="/var/log/frpc.log"

generate_password() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1
}

send_webhook() {
    local event="$1"
    local message="$2"
    
    if [ -z "$WEBHOOK_URL" ]; then
        return
    fi
    
    local payload=$(cat << EOF
{
  "event": "$event",
  "message": "$message",
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "box_name": "$BOX_NAME",
  "public_ip": "$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo 'unknown')",
  "container_id": "$(hostname)"
}
EOF
)
    
    curl -s -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$payload" --max-time 10 > /dev/null 2>&1 || true
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Webhook sent: $event"
}

if [ -z "$SERVER_ADDR" ] || [ -z "$SERVER_PORT" ] || [ -z "$AUTH_TOKEN" ]; then
    echo "ERROR: Required environment variables not set"
    echo "Required: SERVER_ADDR, SERVER_PORT, AUTH_TOKEN"
    echo ""
    echo "Example:"
    echo "  docker run -e SERVER_ADDR=103.166.185.156 -e SERVER_PORT=7000 -e AUTH_TOKEN=mytoken ..."
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Generating configuration..."
    
    PORT_SUFFIX=${PORT_SUFFIX:-$(printf "%03d" $((RANDOM % 999 + 1)))}
    SOCKS5_PORT=${SOCKS5_PORT:-"51${PORT_SUFFIX}"}
    HTTP_PORT=${HTTP_PORT:-"52${PORT_SUFFIX}"}
    ADMIN_PORT=${ADMIN_PORT:-"53${PORT_SUFFIX}"}
    
    PROXY_USER=${PROXY_USER:-$(generate_password)}
    PROXY_PASS=${PROXY_PASS:-$(generate_password)}
    ADMIN_USER=${ADMIN_USER:-"admin"}
    ADMIN_PASS=${ADMIN_PASS:-$(generate_password)}
    
    BOX_NAME=${BOX_NAME:-"Box-Docker-${PORT_SUFFIX}"}
    BANDWIDTH_LIMIT=${BANDWIDTH_LIMIT:-"8MB"}
    
    cat > "$CONFIG_FILE" << EOF
serverAddr = "$SERVER_ADDR"
serverPort = $SERVER_PORT
loginFailExit = true

webServer.addr = "0.0.0.0"
webServer.port = 7400
webServer.user = "$ADMIN_USER"
webServer.password = "$ADMIN_PASS"

auth.method = "token"
auth.token = "$AUTH_TOKEN"

[[proxies]]
name = "$BOX_NAME - SOCKS5"
type = "tcp"
remotePort = $SOCKS5_PORT
transport.bandwidthLimit = "$BANDWIDTH_LIMIT"

[proxies.plugin]
type = "socks5"
username = "$PROXY_USER"
password = "$PROXY_PASS"

[[proxies]]
name = "$BOX_NAME - HTTP"
type = "tcp"
remotePort = $HTTP_PORT
transport.bandwidthLimit = "$BANDWIDTH_LIMIT"

[proxies.plugin]
type = "http_proxy"
httpUser = "$PROXY_USER"
httpPassword = "$PROXY_PASS"

[[proxies]]
name = "$BOX_NAME - Admin"
type = "tcp"
localIP = "127.0.0.1"
localPort = 7400
remotePort = $ADMIN_PORT
EOF

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuration generated!"
    echo ""
    echo "=========================================="
    echo "  FRPC Docker Container"
    echo "=========================================="
    echo "Box Name: $BOX_NAME"
    echo "Server: $SERVER_ADDR:$SERVER_PORT"
    echo ""
    echo "SOCKS5 Proxy:"
    echo "  Address: $SERVER_ADDR:$SOCKS5_PORT"
    echo "  Username: $PROXY_USER"
    echo "  Password: $PROXY_PASS"
    echo ""
    echo "HTTP Proxy:"
    echo "  Address: $SERVER_ADDR:$HTTP_PORT"
    echo "  Username: $PROXY_USER"
    echo "  Password: $PROXY_PASS"
    echo ""
    echo "Admin API:"
    echo "  Address: $SERVER_ADDR:$ADMIN_PORT"
    echo "  Username: $ADMIN_USER"
    echo "  Password: $ADMIN_PASS"
    echo "=========================================="
    echo ""
    
    send_webhook "container_started" "FRPC container started with box $BOX_NAME"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting frpc..."

exec /usr/local/bin/frpc -c "$CONFIG_FILE"
