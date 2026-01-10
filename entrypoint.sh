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
    
    local public_ip=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo 'unknown')
    
    local payload=$(cat << EOF
{
  "event": "$event",
  "message": "$message",
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "box_name": "$BOX_NAME",
  "public_ip": "$public_ip",
  "container_id": "$(hostname)",
  "server": "$SERVER_ADDR:$SERVER_PORT",
  "proxies": {
    "socks5": {
      "port": ${SOCKS5_PORT:-0},
      "address": "$SERVER_ADDR:${SOCKS5_PORT:-0}",
      "username": "${PROXY_USER:-}",
      "password": "${PROXY_PASS:-}",
      "quick": "$SERVER_ADDR:${SOCKS5_PORT:-0}:${PROXY_USER:-}:${PROXY_PASS:-}"
    },
    "http": {
      "port": ${HTTP_PORT:-0},
      "address": "$SERVER_ADDR:${HTTP_PORT:-0}",
      "username": "${PROXY_USER:-}",
      "password": "${PROXY_PASS:-}",
      "quick": "$SERVER_ADDR:${HTTP_PORT:-0}:${PROXY_USER:-}:${PROXY_PASS:-}"
    },
    "admin_api": {
      "port": ${ADMIN_PORT:-0},
      "address": "$SERVER_ADDR:${ADMIN_PORT:-0}",
      "username": "${ADMIN_USER:-admin}",
      "password": "${ADMIN_PASS:-}"
    },
    "config_proxy": {
      "port": ${CONFIG_PROXY_PORT:-0},
      "address": "$SERVER_ADDR:${CONFIG_PROXY_PORT:-0}",
      "description": "PUT /api/config to update+reload+save"
    }
  }
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
    echo ""
    echo "Required:"
    echo "  SERVER_ADDR  - FRP server IP/domain"
    echo "  SERVER_PORT  - FRP server port"
    echo "  AUTH_TOKEN   - Authentication token"
    echo ""
    echo "Optional:"
    echo "  BOX_NAME     - Box name (auto-generated if not set)"
    echo ""
    echo "Example:"
    echo "  docker run -e SERVER_ADDR=x.x.x.x -e SERVER_PORT=7000 -e AUTH_TOKEN=xxx ..."
    echo ""
    echo "Or use docker-compose with .env file"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Generating configuration..."
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Using existing configuration..."
    # Read all info from existing config
    ADMIN_USER=$(grep 'webServer.user' "$CONFIG_FILE" | cut -d'"' -f2)
    ADMIN_PASS=$(grep 'webServer.password' "$CONFIG_FILE" | cut -d'"' -f2)
    BOX_NAME=$(grep -m1 'name = ' "$CONFIG_FILE" | cut -d'"' -f2 | sed 's/ - .*//')
    PROXY_USER=$(grep 'username = ' "$CONFIG_FILE" | head -1 | cut -d'"' -f2)
    PROXY_PASS=$(grep 'password = ' "$CONFIG_FILE" | head -1 | cut -d'"' -f2)
    SOCKS5_PORT=$(grep 'remotePort' "$CONFIG_FILE" | head -1 | awk '{print $3}')
    HTTP_PORT=$(grep 'remotePort' "$CONFIG_FILE" | head -2 | tail -1 | awk '{print $3}')
    ADMIN_PORT=$(grep 'remotePort' "$CONFIG_FILE" | tail -1 | awk '{print $3}')
    
    echo ""
    echo "=========================================="
    echo "  FRPC Docker Container (existing config)"
    echo "=========================================="
    echo "Box Name: $BOX_NAME"
    echo "Server: $SERVER_ADDR:$SERVER_PORT"
    echo ""
    echo "SOCKS5 Proxy:"
    echo "  Address: $SERVER_ADDR:$SOCKS5_PORT"
    echo "  Username: $PROXY_USER"
    echo "  Password: $PROXY_PASS"
    echo "  Quick: $SERVER_ADDR:$SOCKS5_PORT:$PROXY_USER:$PROXY_PASS"
    echo ""
    echo "HTTP Proxy:"
    echo "  Address: $SERVER_ADDR:$HTTP_PORT"
    echo "  Username: $PROXY_USER"
    echo "  Password: $PROXY_PASS"
    echo "  Quick: $SERVER_ADDR:$HTTP_PORT:$PROXY_USER:$PROXY_PASS"
    echo ""
    echo "Admin API:"
    echo "  Address: $SERVER_ADDR:$ADMIN_PORT"
    echo "  Username: $ADMIN_USER"
    echo "  Password: $ADMIN_PASS"
    echo "=========================================="
    echo ""
fi

if [ ! -f "$CONFIG_FILE" ]; then
    
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

[[proxies]]
name = "$BOX_NAME - ConfigProxy"
type = "tcp"
localIP = "127.0.0.1"
localPort = 7401
remotePort = $((ADMIN_PORT + 1000))
EOF

    CONFIG_PROXY_PORT=$((ADMIN_PORT + 1000))

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
    echo "  Quick: $SERVER_ADDR:$SOCKS5_PORT:$PROXY_USER:$PROXY_PASS"
    echo ""
    echo "HTTP Proxy:"
    echo "  Address: $SERVER_ADDR:$HTTP_PORT"
    echo "  Username: $PROXY_USER"
    echo "  Password: $PROXY_PASS"
    echo "  Quick: $SERVER_ADDR:$HTTP_PORT:$PROXY_USER:$PROXY_PASS"
    echo ""
    echo "Admin API:"
    echo "  Address: $SERVER_ADDR:$ADMIN_PORT"
    echo "  Username: $ADMIN_USER"
    echo "  Password: $ADMIN_PASS"
    echo ""
    echo "Config Proxy (auto-save):"
    echo "  Address: $SERVER_ADDR:$CONFIG_PROXY_PORT"
    echo "  PUT /api/config → update + reload + save"
    echo "=========================================="
    echo ""
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting frpc..."

# Start frpc in background
/usr/local/bin/frpc -c "$CONFIG_FILE" &
FRPC_PID=$!

# Wait for frpc to connect
sleep 8

# Check if frpc is running and proxies are registered
check_frpc_status() {
    if ! kill -0 $FRPC_PID 2>/dev/null; then
        return 1
    fi
    
    local status=$(curl -s --max-time 5 -u "$ADMIN_USER:$ADMIN_PASS" "http://127.0.0.1:7400/api/status" 2>/dev/null)
    if [ -z "$status" ]; then
        return 1
    fi
    
    # Check if any proxy has "running" status
    if echo "$status" | grep -q '"status":"running"'; then
        return 0
    fi
    
    return 1
}

if check_frpc_status; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] frpc connected successfully! Proxies are running."
    send_webhook "container_ready" "FRPC proxies are running for box $BOX_NAME"
else
    # Get error from logs
    FRPC_LOGS=$(cat /var/log/frpc.log 2>/dev/null | tail -10 | tr '\n' '|')
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: frpc may not be fully connected"
    
    # Check specific errors
    if cat /var/log/frpc.log 2>/dev/null | grep -qi "token"; then
        send_webhook "container_error" "Token mismatch - check AUTH_TOKEN|$FRPC_LOGS"
    elif cat /var/log/frpc.log 2>/dev/null | grep -qi "port"; then
        send_webhook "container_error" "Port error - port may be in use|$FRPC_LOGS"
    else
        send_webhook "container_error" "frpc connection issue|$FRPC_LOGS"
    fi
fi

# Config Proxy Server - lắng nghe port 7401
# Khi nhận PUT /api/config -> forward to frpc -> reload -> save to file ngay lập tức
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting config proxy on port 7401..."
(
    while true; do
        # Simple HTTP server using netcat
        { 
            read -r REQUEST_LINE
            METHOD=$(echo "$REQUEST_LINE" | cut -d' ' -f1)
            PATH=$(echo "$REQUEST_LINE" | cut -d' ' -f2)
            
            # Read headers
            CONTENT_LENGTH=0
            while read -r HEADER; do
                HEADER=$(echo "$HEADER" | tr -d '\r')
                [ -z "$HEADER" ] && break
                if echo "$HEADER" | grep -qi "content-length"; then
                    CONTENT_LENGTH=$(echo "$HEADER" | cut -d':' -f2 | tr -d ' ')
                fi
            done
            
            # Read body
            BODY=""
            if [ "$CONTENT_LENGTH" -gt 0 ] 2>/dev/null; then
                BODY=$(dd bs=1 count="$CONTENT_LENGTH" 2>/dev/null)
            fi
            
            # Handle requests
            if [ "$PATH" = "/api/config" ] && [ "$METHOD" = "PUT" ]; then
                # 1. Update config
                curl -s -X PUT -u "$ADMIN_USER:$ADMIN_PASS" \
                    -H "Content-Type: text/plain" \
                    -d "$BODY" http://127.0.0.1:7400/api/config
                
                # 2. Reload
                curl -s -u "$ADMIN_USER:$ADMIN_PASS" http://127.0.0.1:7400/api/reload
                
                # 3. Save to file immediately
                curl -s -u "$ADMIN_USER:$ADMIN_PASS" http://127.0.0.1:7400/api/config > "$CONFIG_FILE"
                
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Config updated and saved to file"
                
                echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"updated\",\"saved\":true}"
            elif [ "$PATH" = "/api/save" ]; then
                # Manual save endpoint
                curl -s -u "$ADMIN_USER:$ADMIN_PASS" http://127.0.0.1:7400/api/config > "$CONFIG_FILE"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Config saved to file"
                echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"saved\"}"
            else
                # Forward other requests to frpc
                RESP=$(curl -s -u "$ADMIN_USER:$ADMIN_PASS" "http://127.0.0.1:7400$PATH")
                echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n$RESP"
            fi
        } | nc -l -p 7401 -q 1 2>/dev/null || sleep 1
    done
) &

# Wait for frpc process (keep container running)
wait $FRPC_PID

