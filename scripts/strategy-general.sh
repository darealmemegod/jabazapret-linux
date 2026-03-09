#!/bin/bash
# DESC: General (recommended)
# Linux port of general.bat from jabazapret/Flowseal

set -euo pipefail
source "$(dirname "$0")/common.sh"

NFQWS=$(find_nfqws)
if [ -z "$NFQWS" ]; then
    echo "[ERROR] nfqws binary not found. Download it from the app first." >&2
    exit 1
fi

IFACE_USED=$(detect_iface)
TCP=$(tcp_ports)
UDP=$(udp_ports)

echo "[strategy] general"
echo "[iface]    ${IFACE_USED:-any}"
echo "[game]     ${GAME_FILTER:-0}"
echo "[ipset]    ${IPSET_FILTER:-none}"

kill_nfqws

# Setup firewall rules (requires root)
if [ "$(id -u)" -ne 0 ]; then
    echo "[WARN] Not root — trying sudo for nftables..."
    sudo bash -c "$(declare -f setup_nftables cleanup_nftables); FWMARK=$FWMARK QNUM=$QNUM setup_nftables '$IFACE_USED' '$TCP' '$UDP'"
else
    setup_nftables "$IFACE_USED" "$TCP" "$UDP"
fi

# Hostlist args
HOSTLIST_ARGS="--hostlist=${LISTS_DIR}/list-general.txt \
  --hostlist-exclude=${LISTS_DIR}/list-exclude.txt \
  --ipset-exclude=${LISTS_DIR}/ipset-exclude.txt"

# IPSet filter
IPSET_ARG=""
if [ "${IPSET_FILTER:-none}" = "loaded" ]; then
    IPSET_ARG="--ipset=${LISTS_DIR}/ipset-all.txt"
fi

echo "[nfqws] Starting..."

exec "$NFQWS" \
  --dpi-desync-fwmark=$FWMARK \
  --qnum=$QNUM \
  \
  --filter-udp=443 \
    $HOSTLIST_ARGS $IPSET_ARG \
    --dpi-desync=fake \
    --dpi-desync-repeats=6 \
    --dpi-desync-fake-quic="${BIN_DIR}/quic_initial_www_google_com.bin" \
  --new \
  \
  --filter-udp=19294-19344,50000-50100 \
    --filter-l7=discord,stun \
    --dpi-desync=fake \
    --dpi-desync-repeats=6 \
  --new \
  \
  --filter-tcp=2053,2083,2087,2096,8443 \
    --hostlist-domains=discord.media \
    --dpi-desync=multisplit \
    --dpi-desync-split-seqovl=681 \
    --dpi-desync-split-pos=1 \
    --dpi-desync-split-seqovl-pattern="${BIN_DIR}/tls_clienthello_www_google_com.bin" \
  --new \
  \
  --filter-tcp=443 \
    --hostlist="${LISTS_DIR}/list-google.txt" \
    --ip-id=zero \
    --dpi-desync=multisplit \
    --dpi-desync-split-seqovl=681 \
    --dpi-desync-split-pos=1 \
    --dpi-desync-split-seqovl-pattern="${BIN_DIR}/tls_clienthello_www_google_com.bin" \
  --new \
  \
  --filter-tcp=80,443 \
    $HOSTLIST_ARGS $IPSET_ARG \
    --dpi-desync=multisplit \
    --dpi-desync-split-seqovl=681 \
    --dpi-desync-split-pos=1 \
    --dpi-desync-split-seqovl-pattern="${BIN_DIR}/tls_clienthello_www_google_com.bin"
