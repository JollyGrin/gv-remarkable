#!/usr/bin/env bash
# Remove the spike's dummy document (fixed UUID only — touches nothing else)
# and restart xochitl. Honors XOCHITL_DIR for fake mode.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

if [ -n "${XOCHITL_DIR:-}" ]; then
    rm -rf "$XOCHITL_DIR/$RM_UUID".*
    echo "fake mode: removed $RM_UUID.* from $XOCHITL_DIR"
    exit 0
fi

ssh -o BatchMode=yes -o ConnectTimeout=5 "$RM_USER@$RM_HOST" \
    "systemctl stop xochitl && rm -rf '$RM_XOCHITL_DIR/$RM_UUID'.* && systemctl start xochitl"
echo "removed $RM_UUID.* from $RM_USER@$RM_HOST and restarted xochitl"
