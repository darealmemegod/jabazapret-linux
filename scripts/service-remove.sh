#!/bin/bash
# service-remove.sh — remove zapret systemd service

if [ "$(id -u)" -ne 0 ]; then
    sudo systemctl stop zapret 2>/dev/null || true
    sudo systemctl disable zapret 2>/dev/null || true
    sudo rm -f /etc/systemd/system/zapret.service
    sudo systemctl daemon-reload
else
    systemctl stop zapret 2>/dev/null || true
    systemctl disable zapret 2>/dev/null || true
    rm -f /etc/systemd/system/zapret.service
    systemctl daemon-reload
fi

echo "Service removed."
