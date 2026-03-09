#!/bin/bash
# common.sh — shared nftables/nfqws setup helpers

QNUM=${QNUM:-220}
FWMARK=${FWMARK:-0x40000000}

# Detect nfqws binary
find_nfqws() {
    if [ -x "$BIN_DIR/nfqws" ]; then
        echo "$BIN_DIR/nfqws"
    elif command -v nfqws &>/dev/null; then
        command -v nfqws
    else
        echo ""
    fi
}

# Detect default interface
detect_iface() {
    if [ -n "$IFACE" ] && [ "$IFACE" != "auto" ]; then
        echo "$IFACE"
    else
        ip route show default 2>/dev/null | awk '/^default/ {print $5; exit}'
    fi
}

# Build TCP ports list (includes game ports if GAME_FILTER=1)
tcp_ports() {
    local base="80,443,2053,2083,2087,2096,8443"
    if [ "${GAME_FILTER:-0}" = "1" ]; then
        echo "${base},1024-65535"
    else
        echo "$base"
    fi
}

# Build UDP ports list
udp_ports() {
    local base="443,19294-19344,50000-50100"
    if [ "${GAME_FILTER:-0}" = "1" ]; then
        echo "${base},1024-65535"
    else
        echo "$base"
    fi
}

# Setup nftables rules
setup_nftables() {
    local iface="$1"
    local tcp="$2"
    local udp="$3"

    echo "[nft] Setting up nftables rules..."

    # Clean up any existing zapret table
    nft delete table inet zapret 2>/dev/null

    # Create table and chains
    nft add table inet zapret
    nft add chain inet zapret output '{ type filter hook output priority -100; policy accept; }'
    nft add chain inet zapret prerouting '{ type filter hook prerouting priority -100; policy accept; }'

    # Mark bit to avoid re-queuing
    nft add rule inet zapret output meta mark and $FWMARK eq $FWMARK accept

    # TCP output
    if [ -n "$tcp" ]; then
        if [ -n "$iface" ]; then
            nft add rule inet zapret output oifname "$iface" tcp dport \{ $tcp \} counter queue num $QNUM bypass
        else
            nft add rule inet zapret output tcp dport \{ $tcp \} counter queue num $QNUM bypass
        fi
    fi

    # UDP output
    if [ -n "$udp" ]; then
        if [ -n "$iface" ]; then
            nft add rule inet zapret output oifname "$iface" udp dport \{ $udp \} counter queue num $QNUM bypass
        else
            nft add rule inet zapret output udp dport \{ $udp \} counter queue num $QNUM bypass
        fi
    fi

    echo "[nft] Rules applied."
}

# Cleanup nftables
cleanup_nftables() {
    nft delete table inet zapret 2>/dev/null && echo "[nft] Cleaned up." || true
}

# Kill any running nfqws
kill_nfqws() {
    pkill -x nfqws 2>/dev/null || true
    sleep 0.5
}
