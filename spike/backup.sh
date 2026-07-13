#!/usr/bin/env bash
# Pre-flight backup of the tablet's user data into a local timestamped dir.
#
#   ./backup.sh        # -> spike/backups/<timestamp>/{xochitl/, version.txt, firmware.txt}
#
# STRICTLY READ-ONLY on the device: reads ~/.local/share/remarkable/xochitl/
# and two version files; writes nothing and installs nothing tablet-side.
#
# Prefers `rsync -avz`, but stock reMarkable firmware ships no rsync binary,
# so when the remote side lacks it we fall back to tar-over-ssh (busybox tar
# is always present). Same RM_HOST/RM_USER/BatchMode conventions as push.sh.
#
# Fake mode: with XOCHITL_DIR set, copies from that local dir and writes
# placeholder version stamps (exercised by test.sh).
#
# Restore is deliberately manual — see RUNBOOK.md step 0. No restore.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

stamp="$(date +%Y%m%d-%H%M%S)"
dest="${BACKUP_DIR:-$SPIKE_DIR/backups}/$stamp"
mkdir -p "$dest/xochitl"

if [ -n "${XOCHITL_DIR:-}" ]; then
    cp -R "$XOCHITL_DIR/." "$dest/xochitl/"
    printf 'fake-xochitl mode: no device /etc/version\n' > "$dest/version.txt"
    printf 'fake-xochitl mode: no device firmware\n' > "$dest/firmware.txt"
    echo "fake mode: backed up $XOCHITL_DIR -> $dest"
    exit 0
fi

ssh_opts=(-o BatchMode=yes -o ConnectTimeout=5)
remote="$RM_USER@$RM_HOST"

echo "backing up $remote:$RM_XOCHITL_DIR/ -> $dest/xochitl/ ..."
rsync_ok=0
if command -v rsync >/dev/null 2>&1; then
    if rsync -avz -e "ssh -o BatchMode=yes -o ConnectTimeout=5" \
        "$remote:$RM_XOCHITL_DIR/" "$dest/xochitl/"; then
        rsync_ok=1
    else
        echo "rsync failed (stock firmware has no rsync binary) — falling back to tar-over-ssh" >&2
    fi
fi
if [ "$rsync_ok" != 1 ]; then
    ssh "${ssh_opts[@]}" "$remote" "tar -C '$RM_XOCHITL_DIR' -cf - ." \
        | tar -xf - -C "$dest/xochitl"
fi

ssh "${ssh_opts[@]}" "$remote" "cat /etc/version 2>/dev/null || true" \
    > "$dest/version.txt"
ssh "${ssh_opts[@]}" "$remote" \
    "cat /usr/share/remarkable/update.conf 2>/dev/null || cat /etc/os-release 2>/dev/null || true" \
    > "$dest/firmware.txt"

count="$(find "$dest/xochitl" -type f | wc -l | tr -d ' ')"
echo "done: $count files, $(du -sh "$dest" | cut -f1) in $dest"
echo "device /etc/version: $(head -1 "$dest/version.txt" 2>/dev/null || echo '?')"
echo "restore is manual (RUNBOOK step 0): copy $dest/xochitl/* back, restart xochitl"
