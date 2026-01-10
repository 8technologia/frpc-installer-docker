#!/usr/bin/env python3
"""
FRPC Config Proxy Server
- Handles HTTP Basic Auth (external)
- Forwards requests to frpc admin API (with fixed internal credentials)
- Auto-saves config after PUT /api/config
- External auth can change, internal frpc auth stays fixed
"""

import http.server
import base64
import os
import re
import json
import time
from urllib.request import Request, urlopen
from urllib.error import URLError

CONFIG_FILE = os.environ.get('CONFIG_FILE', '/etc/frpc/frpc.toml')
FRPC_ADMIN_URL = 'http://127.0.0.1:7402'

# Fixed internal credentials for talking to frpc (never changes)
INTERNAL_USER = os.environ.get('ADMIN_USER', 'admin')
INTERNAL_PASS = os.environ.get('ADMIN_PASS', '')

# External credentials for API auth (can change via config)
external_credentials = {
    'user': INTERNAL_USER,
    'pass': INTERNAL_PASS
}

def read_credentials_from_config():
    """Read admin credentials from config file for external auth"""
    try:
        with open(CONFIG_FILE, 'r') as f:
            content = f.read()
        
        user_match = re.search(r'webServer\.user\s*=\s*"([^"]+)"', content)
        pass_match = re.search(r'webServer\.password\s*=\s*"([^"]+)"', content)
        
        if user_match and pass_match:
            return user_match.group(1), pass_match.group(1)
    except:
        pass
    return None, None

def update_external_credentials():
    """Update external credentials from config file"""
    user, passwd = read_credentials_from_config()
    if user and passwd:
        external_credentials['user'] = user
        external_credentials['pass'] = passwd
        print(f"[PROXY] External credentials loaded: user={user}")

class ConfigProxyHandler(http.server.BaseHTTPRequestHandler):
    
    def log_message(self, format, *args):
        """Custom log format"""
        print(f"[PROXY] {args[0]}")
    
    def check_auth(self):
        """Verify HTTP Basic Auth against external credentials"""
        auth_header = self.headers.get('Authorization', '')
        if not auth_header.startswith('Basic '):
            return False
        
        try:
            encoded = auth_header[6:]
            decoded = base64.b64decode(encoded).decode('utf-8')
            username, password = decoded.split(':', 1)
            return username == external_credentials['user'] and password == external_credentials['pass']
        except:
            return False
    
    def send_unauthorized(self):
        """Send 401 response"""
        self.send_response(401)
        self.send_header('WWW-Authenticate', 'Basic realm="frpc"')
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{"error":"unauthorized"}')
    
    def forward_to_frpc(self, method='GET', path=None, body=None):
        """Forward request to frpc admin API with FIXED internal credentials"""
        if path is None:
            path = self.path
        url = f"{FRPC_ADMIN_URL}{path}"
        
        # Always use FIXED internal credentials
        auth_str = f"{INTERNAL_USER}:{INTERNAL_PASS}"
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
        config_data = self.forward_to_frpc('GET', '/api/config')
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
            # Check if new config has different admin password
            new_user, new_pass = None, None
            if body:
                body_str = body.decode('utf-8')
                user_match = re.search(r'webServer\.user\s*=\s*"([^"]+)"', body_str)
                pass_match = re.search(r'webServer\.password\s*=\s*"([^"]+)"', body_str)
                if user_match and pass_match:
                    new_user = user_match.group(1)
                    new_pass = pass_match.group(1)
            
            # 1. Update config in frpc
            self.forward_to_frpc('PUT', '/api/config', body)
            
            # 2. Reload frpc
            self.forward_to_frpc('GET', '/api/reload')
            print("[PROXY] Config updated and reload triggered")
            
            # 3. Wait for reload
            time.sleep(0.5)
            
            # 4. Update EXTERNAL credentials (for proxy auth)
            if new_user and new_pass:
                external_credentials['user'] = new_user
                external_credentials['pass'] = new_pass
                print(f"[PROXY] External credentials updated: user={new_user}")
            
            # 5. Save to file
            self.save_config()
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status":"updated","saved":true}')
        else:
            response = self.forward_to_frpc('PUT', self.path, body)
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(response)

def run_server(port=7400):
    """Start HTTP server"""
    # Load external credentials from existing config
    update_external_credentials()
    
    print(f"[PROXY] Config proxy server running on port {port}")
    print(f"[PROXY] External auth user: {external_credentials['user']}")
    print(f"[PROXY] Internal frpc user: {INTERNAL_USER} (fixed)")
    
    server = http.server.HTTPServer(('0.0.0.0', port), ConfigProxyHandler)
    server.serve_forever()

if __name__ == '__main__':
    run_server()
