#!/usr/bin/env python3
"""
FRPC Config Proxy Server
- Handles HTTP Basic Auth
- Forwards requests to frpc admin API
- Auto-saves config after PUT /api/config
- Auto-updates credentials when config changes
"""

import http.server
import base64
import os
import re
import json
from urllib.request import Request, urlopen
from urllib.error import URLError

CONFIG_FILE = os.environ.get('CONFIG_FILE', '/etc/frpc/frpc.toml')
FRPC_ADMIN_URL = 'http://127.0.0.1:7402'

# Mutable credentials - will be updated when config changes
credentials = {
    'user': os.environ.get('ADMIN_USER', 'admin'),
    'pass': os.environ.get('ADMIN_PASS', '')
}

def read_credentials_from_config():
    """Read admin credentials from config file"""
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

def update_credentials():
    """Update credentials from config file"""
    user, passwd = read_credentials_from_config()
    if user and passwd:
        credentials['user'] = user
        credentials['pass'] = passwd
        print(f"[PROXY] Credentials updated: user={user}")

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
            return username == credentials['user'] and password == credentials['pass']
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
        
        # Create request with current credentials
        auth_str = f"{credentials['user']}:{credentials['pass']}"
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
        # Need to get config from frpc's new path
        url = f"{FRPC_ADMIN_URL}/api/config"
        auth_str = f"{credentials['user']}:{credentials['pass']}"
        auth_bytes = base64.b64encode(auth_str.encode()).decode()
        headers = {'Authorization': f'Basic {auth_bytes}'}
        
        try:
            req = Request(url, headers=headers)
            with urlopen(req, timeout=10) as response:
                config_data = response.read()
            
            if config_data and not config_data.startswith(b'{'):
                with open(CONFIG_FILE, 'wb') as f:
                    f.write(config_data)
                print(f"[PROXY] Config saved to {CONFIG_FILE}")
                return True
        except Exception as e:
            print(f"[PROXY] Save failed: {e}")
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
            self.forward_to_frpc('PUT', body)
            
            # 2. Update local credentials BEFORE reload if changed
            if new_user and new_pass:
                credentials['user'] = new_user
                credentials['pass'] = new_pass
                print(f"[PROXY] Credentials updated to: user={new_user}")
            
            # 3. Reload frpc with new credentials
            reload_url = f"{FRPC_ADMIN_URL}/api/reload"
            auth_str = f"{credentials['user']}:{credentials['pass']}"
            auth_bytes = base64.b64encode(auth_str.encode()).decode()
            headers = {'Authorization': f'Basic {auth_bytes}'}
            try:
                req = Request(reload_url, headers=headers)
                urlopen(req, timeout=5)
            except:
                pass
            
            # 4. Save to file
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
    # Read initial credentials from config if exists
    update_credentials()
    
    server = http.server.HTTPServer(('0.0.0.0', port), ConfigProxyHandler)
    print(f"[PROXY] Config proxy server running on port {port}")
    print(f"[PROXY] Auth user: {credentials['user']}")
    server.serve_forever()

if __name__ == '__main__':
    run_server()
