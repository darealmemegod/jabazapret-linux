#!/bin/bash
# download-nfqws.sh — download latest nfqws binary

set -e

ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  ARCH_TAG="x86_64" ;;
    aarch64) ARCH_TAG="aarch64" ;;
    armv7l)  ARCH_TAG="armv7" ;;
    *)       echo "[ERROR] Unsupported arch: $ARCH"; exit 1 ;;
esac

DEST="${BIN_DIR}/nfqws"
mkdir -p "$BIN_DIR"

# Try to get latest release tag from zapret
echo "Fetching latest zapret release..."
LATEST_URL="https://api.github.com/repos/bol-van/zapret/releases/latest"
TAG=$(curl -sf "$LATEST_URL" | grep '"tag_name"' | head -1 | cut -d'"' -f4 || echo "v72.9")
echo "Latest: $TAG"

BASE="https://github.com/bol-van/zapret/releases/download/${TAG}"
FILE="zapret-${TAG}-$(uname -s | tr '[:upper:]' '[:lower:]')-${ARCH_TAG}.tar.gz"
URL="${BASE}/${FILE}"

echo "Downloading: $URL"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

if curl -fL --progress-bar "$URL" -o "$TMP/zapret.tar.gz"; then
    tar -xzf "$TMP/zapret.tar.gz" -C "$TMP" 2>/dev/null || true
    # Find nfqws binary
    BIN=$(find "$TMP" -name "nfqws" -type f | head -1)
    if [ -n "$BIN" ]; then
        cp "$BIN" "$DEST"
        chmod 755 "$DEST"
        echo "✓ nfqws installed to $DEST"
        "$DEST" --version 2>&1 | head -1 || true
    else
        echo "[ERROR] nfqws not found in archive"
        # Fallback: try direct binary URL
        curl -fL "${BASE}/nfqws-linux-${ARCH_TAG}" -o "$DEST" && chmod 755 "$DEST" && echo "✓ Direct download OK"
    fi
else
    echo "[WARN] Release download failed, trying direct binary..."
    # Common direct binary patterns
    for url in \
        "https://github.com/bol-van/zapret/releases/latest/download/nfqws-linux-${ARCH_TAG}" \
        "https://github.com/Flowseal/zapret-discord-youtube/raw/main/bin/nfqws"; do
        if curl -fL "$url" -o "$DEST" 2>/dev/null; then
            chmod 755 "$DEST"
            echo "✓ Downloaded from $url"
            break
        fi
    done
fi

if [ -x "$DEST" ]; then
    echo "✓ nfqws ready: $DEST"
else
    echo "[ERROR] Failed to download nfqws. Please download manually from:"
    echo "  https://github.com/bol-van/zapret/releases"
    echo "  and place the 'nfqws' binary in: $BIN_DIR"
    exit 1
fi
