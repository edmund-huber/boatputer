#!/bin/bash
set -euo pipefail

echo "boatputer" > /etc/hostname
sed -i "s/raspberrypi/boatputer/g" /etc/hosts

# Triggers Raspbian's first-boot mechanism to permanently enable sshd (it deletes this file after)
touch /boot/firmware/ssh

apt-get update
apt-get install -y --no-install-recommends \
    python3
apt-get clean
rm -rf /var/lib/apt/lists/*
