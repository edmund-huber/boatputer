#!/bin/bash
set -euo pipefail

echo "boatputer" > /etc/hostname
sed -i "s/raspberrypi/boatputer/g" /etc/hosts

# Triggers Raspbian's first-boot mechanism to permanently enable sshd (it deletes this file after)
touch /boot/firmware/ssh

# credentials: user / password
echo 'user:$6$0OB1OQvdH39TqH57$vtc6JKQ9kYMH0AjCpEb8xW0ptZnuiTdejcoAeqWpCMIrV9ICuS7mm9YU0zAKzRzcEom/RIrr37iAkYKdxTGTG.' > /boot/firmware/userconf.txt

# Route the hardware UART to the GPIO pins (40-pin header, pins 8/10)
grep -qxF 'enable_uart=1' /boot/firmware/config.txt || echo 'enable_uart=1' >> /boot/firmware/config.txt

apt-get update
apt-get install -y --no-install-recommends \
    python3 \
    avahi-daemon
apt-get clean
rm -rf /var/lib/apt/lists/*

raspi-config nonint do_wifi_country US

# NetworkManager AP connection profile — NM handles DHCP via its built-in dnsmasq (method=shared)
mkdir -p /etc/NetworkManager/system-connections
cat > /etc/NetworkManager/system-connections/boatputer-ap.nmconnection <<'EOF'
[connection]
id=boatputer-ap
type=wifi
interface-name=wlan0
autoconnect=true

[wifi]
mode=ap
ssid=boatputer

[wifi-security]
key-mgmt=wpa-psk
psk=b1gf4tg0rbst3r

[ipv4]
method=shared
address1=192.168.4.1/24

[ipv6]
method=disabled
EOF

chmod 600 /etc/NetworkManager/system-connections/boatputer-ap.nmconnection

cat > /usr/local/bin/boaterface.py <<'EOF'
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime, timezone

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>boaterface</title></head>
<body>
<h1>{datetime.now(timezone.utc).strftime('%H:%M:%S UTC')}</h1>
</body>
</html>""".encode()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.send_header('Content-Length', len(body))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass

HTTPServer(('', 80), Handler).serve_forever()
EOF

chmod +x /usr/local/bin/boaterface.py

cat > /etc/systemd/system/boaterface.service <<'EOF'
[Unit]
Description=boaterface
After=network.target

[Service]
ExecStart=/usr/local/bin/boaterface.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable boaterface.service
