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

python3 -c "import urllib.request; urllib.request.urlretrieve('https://unpkg.com/htmx.org@1.9.10/dist/htmx.min.js', '/usr/local/lib/boaterface/htmx.min.js')"

chmod +x /usr/local/lib/boaterface/server.py

cat > /etc/systemd/system/boaterface.service <<'EOF'
[Unit]
Description=boaterface
After=network.target

[Service]
ExecStart=/usr/local/lib/boaterface/server.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable boaterface.service
