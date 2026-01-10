#!/usr/bin/env python3
"""
FRPC Config Proxy Server
- Handles HTTP Basic Auth
- Forwards requests to frpc admin API
- Auto-saves config after PUT /api/config
"""

import http.server
import base64
import os
import subprocess
import json
from urllib.request import Request, urlopen
from urllib.error import URLError

# Get credentials from environment
ADMIN_USER = os.environ.get('ADMIN_USER', 'admin')
ADMIN_PASS = os.environ.get('ADMIN_PASS', '')
CONFIG_FILE = os.environ.get('CONFIG_FILE', '/etc/frpc/frpc.toml')
FRPC_ADMIN_URL = 'http://127.0.0.1:7402'

class ConfigProxyHandler(http.server.BaseHTTPRequestHandler):
    
    def log_message(self, format, *args):
        """Custom log format"""
        print(f"[PROXY] {args[0]}")
    
    def check_auth(self):
        """Verify HTTP Basic Auth"""
        auth_header = self.headers.get('Authorization', '')
        if not auth_header.startswith('Basic '):
            return False
        
        try:
            encoded = auth_header[6:]
            decoded = base64.b64decode(encoded).decode('utf-8')
            username, password = decoded.split(':', 1)
            return username == ADMIN_USER and password == ADMIN_PASS
        except:
            return False
    
    def send_unauthorized(self):
        """Send 401 response"""
        self.send_response(401)
        self.send_header('WWW-Authenticate', 'Basic realm="frpc"')
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{"error":"unauthorized"}')
    
    def forward_to_frpc(self, method='GET', body=None):
        """Forward request to frpc admin API"""
        url = f"{FRPC_ADMIN_URL}{self.path}"
        
        # Create request with auth
        auth_str = f"{ADMIN_USER}:{ADMIN_PASS}"
        auth_bytes = base64.b64encode(auth_str.encode()).decode()
        
        headers = {'Authorization': f'Basic {auth_bytes}'}
        if body:
            headers['Content-Type'] = 'text/plain'
        
        try:
            req = Request(url, data=body, headers=headers, method=method)
            with urlopen(req, timeout=10) as response:
                return response.read()
        except URLError as e:
            return json.dumps({"error": str(e)}).encode()
    
    def save_config(self):
        """Save current config to file"""
        config_data = self.forward_to_frpc('GET')
        if config_data and not config_data.startswith(b'{'):
            with open(CONFIG_FILE, 'wb') as f:
                f.write(config_data)
            print(f"[PROXY] Config saved to {CONFIG_FILE}")
            return True
        return False
    
    def do_GET(self):
        """Handle GET requests"""
        if not self.check_auth():
            self.send_unauthorized()
            return
        
        response = self.forward_to_frpc('GET')
        
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(response)
    
    def do_PUT(self):
        """Handle PUT requests - with auto-save for /api/config"""
        if not self.check_auth():
            self.send_unauthorized()
            return
        
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length) if content_length > 0 else None
        
        if self.path == '/api/config':
            # 1. Update config
            self.forward_to_frpc('PUT', body)
            
            # 2. Reload
            self.forward_to_frpc('GET')
            urlopen(f"{FRPC_ADMIN_URL}/api/reload", timeout=5)
            
            # 3. Save to file
            self.save_config()
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status":"updated","saved":true}')
        else:
            response = self.forward_to_frpc('PUT', body)
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(response)

def run_server(port=7400):
    """Start HTTP server"""
    server = http.server.HTTPServer(('0.0.0.0', port), ConfigProxyHandler)
    print(f"[PROXY] Config proxy server running on port {port}")
    server.serve_forever()

if __name__ == '__main__':
    run_server()
