#!/bin/bash
# cleanup.sh — remove nftables rules and stop nfqws

pkill -x nfqws 2>/dev/null || true

if command -v nft &>/dev/null; then
    if [ "$(id -u)" -ne 0 ]; then
        sudo nft delete table inet zapret 2>/dev/null || true
    else
        nft delete table inet zapret 2>/dev/null || true
    fi
fi

echo "Cleanup complete."
