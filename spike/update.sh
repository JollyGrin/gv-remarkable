#!/usr/bin/env bash
# The in-place refresh loop: re-render with counter+1, overwrite the SAME
# UUID's fileset, restart xochitl. Run it as many times as you like — the
# document identity never changes.
set -euo pipefail
spike_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$spike_dir/render_dummy.sh"
"$spike_dir/push.sh"
