#!/bin/bash
# service-install.sh — install zapret as systemd service
# Usage: ./service-install.sh <strategy> <iface> <app_dir>

STRATEGY="${1:-general}"
IFACE="${2:-auto}"
APP_DIR="${3:-$(dirname "$(readlink -f "$0")")/../}"

SERVICE_FILE="/etc/systemd/system/zapret.service"

cat > /tmp/zapret.service << EOF
[Unit]
Description=JabaZapret DPI Bypass (nfqws)
After=network.target

[Service]
Type=forking
Environment="ZAPRET_DIR=${APP_DIR}"
Environment="BIN_DIR=${APP_DIR}/bin"
Environment="LISTS_DIR=${APP_DIR}/lists"
Environment="IFACE=${IFACE}"
Environment="GAME_FILTER=0"
Environment="IPSET_FILTER=none"
ExecStart=/bin/bash ${APP_DIR}/scripts/strategy-${STRATEGY}.sh
ExecStop=/bin/bash ${APP_DIR}/scripts/cleanup.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

if [ "$(id -u)" -ne 0 ]; then
    sudo cp /tmp/zapret.service "$SERVICE_FILE"
    sudo systemctl daemon-reload
    sudo systemctl enable zapret
    sudo systemctl start zapret
else
    cp /tmp/zapret.service "$SERVICE_FILE"
    systemctl daemon-reload
    systemctl enable zapret
    systemctl start zapret
fi

echo "Service installed and started."
echo "Use: sudo systemctl status zapret"
