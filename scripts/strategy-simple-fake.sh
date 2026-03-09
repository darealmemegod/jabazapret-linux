#!/bin/bash
# DESC: Simple Fake
# Linux port of general (SIMPLE FAKE).bat

set -euo pipefail
source "$(dirname "$0")/common.sh"

NFQWS=$(find_nfqws)
[ -z "$NFQWS" ] && { echo "[ERROR] nfqws not found" >&2; exit 1; }

IFACE_USED=$(detect_iface)
TCP=$(tcp_ports)
UDP=$(udp_ports)

echo "[strategy] simple-fake"
kill_nfqws

if [ "$(id -u)" -ne 0 ]; then
    sudo bash -c "$(declare -f setup_nftables cleanup_nftables); FWMARK=$FWMARK QNUM=$QNUM setup_nftables '$IFACE_USED' '$TCP' '$UDP'"
else
    setup_nftables "$IFACE_USED" "$TCP" "$UDP"
fi

HOSTLIST="--hostlist=${LISTS_DIR}/list-general.txt \
  --hostlist-exclude=${LISTS_DIR}/list-exclude.txt \
  --ipset-exclude=${LISTS_DIR}/ipset-exclude.txt"

echo "[nfqws] Starting SIMPLE FAKE strategy..."

exec "$NFQWS" \
  --dpi-desync-fwmark=$FWMARK \
  --qnum=$QNUM \
  \
  --filter-udp=443 \
    $HOSTLIST \
    --dpi-desync=fake \
    --dpi-desync-repeats=6 \
    --dpi-desync-fake-quic="${BIN_DIR}/quic_initial_www_google_com.bin" \
  --new \
  \
  --filter-tcp=80,443 \
    $HOSTLIST \
    --dpi-desync=fake \
    --dpi-desync-repeats=6 \
    --dpi-desync-fake-tls="${BIN_DIR}/tls_clienthello_www_google_com.bin"
