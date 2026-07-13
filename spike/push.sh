#!/usr/bin/env bash
# Construct the xochitl fileset for the fixed UUID and deliver it.
#
#   ./push.sh [path/to.pdf]    # default: $OUT_DIR/dummy.pdf
#
# Device mode (default): stop xochitl, scp the fileset to
# ~/.local/share/remarkable/xochitl/, purge stale render caches, start
# xochitl. Parameterized by RM_HOST (default 10.11.99.1) and RM_USER.
#
# Fake-xochitl mode: set XOCHITL_DIR to a local directory — same fileset is
# written there, no ssh, no systemctl. Used by test.sh.
#
# Why stop-before-copy instead of copy-then-restart: xochitl keeps document
# metadata in memory and flushes it to disk when it exits. Copying while it
# runs risks our fresh .metadata being overwritten by its stale in-memory
# copy during the restart's shutdown phase. Stopping first makes the disk
# the single source of truth while we mutate it.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

pdf="${1:-$OUT_DIR/dummy.pdf}"
[ -f "$pdf" ] || die "no PDF at $pdf — run ./render_dummy.sh first"

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

# Epoch milliseconds, as a string — the format xochitl expects.
last_modified="${LAST_MODIFIED_MS:-$(( $(date +%s) * 1000 ))}"

cp "$pdf" "$stage/$RM_UUID.pdf"

cat > "$stage/$RM_UUID.metadata" <<EOF
{
    "deleted": false,
    "lastModified": "$last_modified",
    "metadatamodified": false,
    "modified": false,
    "parent": "",
    "pinned": false,
    "synced": false,
    "type": "DocumentType",
    "version": 0,
    "visibleName": "$VISIBLE_NAME"
}
EOF

cat > "$stage/$RM_UUID.content" <<EOF
{
    "extraMetadata": {},
    "fileType": "pdf",
    "fontName": "",
    "lastOpenedPage": 0,
    "lineHeight": -1,
    "margins": 100,
    "orientation": "portrait",
    "pageCount": 1,
    "textScale": 1,
    "transform": {
        "m11": 1, "m12": 0, "m13": 0,
        "m21": 0, "m22": 1, "m23": 0,
        "m31": 0, "m32": 0, "m33": 1
    }
}
EOF

# One template name per page.
printf 'Blank\n' > "$stage/$RM_UUID.pagedata"

if [ -n "${XOCHITL_DIR:-}" ]; then
    mkdir -p "$XOCHITL_DIR"
    rm -rf "$XOCHITL_DIR/$RM_UUID.cache" "$XOCHITL_DIR/$RM_UUID.thumbnails"
    cp "$stage/$RM_UUID".* "$XOCHITL_DIR/"
    echo "fake mode: fileset for $RM_UUID written to $XOCHITL_DIR"
    exit 0
fi

ssh_opts=(-o BatchMode=yes -o ConnectTimeout=5)
remote="$RM_USER@$RM_HOST"

# OpenSSH >= 9 makes scp use SFTP, which the tablet's dropbear server does
# not speak; -O forces the legacy scp protocol. Older scp has no -O flag.
if scp -O 2>&1 | grep -qi 'unknown option'; then
    scp_cmd=(scp)
else
    scp_cmd=(scp -O)
fi

echo "pushing $RM_UUID to $remote (xochitl will be down briefly)..."
blip_start="$(date +%s)"
ssh "${ssh_opts[@]}" "$remote" \
    "systemctl stop xochitl && rm -rf '$RM_XOCHITL_DIR/$RM_UUID.cache' '$RM_XOCHITL_DIR/$RM_UUID.thumbnails'"
"${scp_cmd[@]}" "${ssh_opts[@]}" -q "$stage/$RM_UUID".* "$remote:$RM_XOCHITL_DIR/"
ssh "${ssh_opts[@]}" "$remote" "systemctl start xochitl"
blip_end="$(date +%s)"

echo "done: $RM_UUID pushed, xochitl stop->start took $((blip_end - blip_start))s"
echo "(UI takes a few more seconds to redraw — note total blip for FINDINGS.md)"
