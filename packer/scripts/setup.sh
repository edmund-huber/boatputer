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
    python3
apt-get clean
rm -rf /var/lib/apt/lists/*
