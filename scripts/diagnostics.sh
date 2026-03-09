#!/bin/bash
# diagnostics.sh — check system requirements

echo "=== JabaZapret Diagnostics ==="
echo ""

# nfqws
echo "--- nfqws binary ---"
if [ -x "${BIN_DIR}/nfqws" ]; then
    echo "✓ Local nfqws: ${BIN_DIR}/nfqws"
    "${BIN_DIR}/nfqws" --version 2>&1 | head -1 || true
elif command -v nfqws &>/dev/null; then
    echo "✓ System nfqws: $(command -v nfqws)"
else
    echo "✗ nfqws NOT FOUND — download it first"
fi
echo ""

# nftables
echo "--- nftables ---"
if command -v nft &>/dev/null; then
    echo "✓ nft found: $(nft --version 2>&1 | head -1)"
    if sudo nft list tables 2>/dev/null | grep -q zapret; then
        echo "✓ zapret table active"
    else
        echo "  (no active zapret table)"
    fi
else
    echo "✗ nft NOT FOUND — install nftables: sudo apt install nftables"
fi
echo ""

# iptables fallback check
echo "--- iptables ---"
if command -v iptables &>/dev/null; then
    echo "✓ iptables: $(iptables --version 2>&1 | head -1)"
else
    echo "  iptables not found (ok if using nftables)"
fi
echo ""

# Network interfaces
echo "--- Interfaces ---"
ip -o link show | awk -F': ' '{print "  "$2}' | grep -v lo
echo ""

# DNS
echo "--- DNS resolver ---"
if grep -q "nameserver" /etc/resolv.conf 2>/dev/null; then
    grep nameserver /etc/resolv.conf | head -3
else
    echo "  Could not read /etc/resolv.conf"
fi
echo ""

# Connectivity
echo "--- Connectivity ---"
for host in discord.com youtube.com www.google.com; do
    if curl -sI --max-time 3 "https://$host" &>/dev/null; then
        echo "✓ $host reachable"
    else
        echo "✗ $host NOT reachable"
    fi
done
echo ""

# Lists
echo "--- Domain lists ---"
for f in list-general.txt list-exclude.txt ipset-exclude.txt; do
    path="${LISTS_DIR}/${f}"
    if [ -f "$path" ]; then
        lines=$(wc -l < "$path")
        echo "✓ $f ($lines entries)"
    else
        echo "✗ $f missing"
    fi
done
echo ""

echo "=== Done ==="
