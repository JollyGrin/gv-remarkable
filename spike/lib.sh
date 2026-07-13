# Shared configuration for the spike scripts. Sourced, never executed.
#
# Every knob is an environment variable with a safe default, so the same
# scripts run against a real tablet (ssh/scp) or a local fake-xochitl dir.

SPIKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Where rendered PDFs and the generation counter live (test.sh points this
# at a temp dir so the repo stays clean).
OUT_DIR="${OUT_DIR:-$SPIKE_DIR/out}"

# Fixed document UUID — the whole point of the spike. push.sh always writes
# the fileset under this UUID; update.sh overwrites the same one.
RM_UUID="${RM_UUID:-deadbeef-cafe-4000-8000-5eed5eed0001}"

# Device connection. 10.11.99.1 is the USB ethernet gadget address.
RM_HOST="${RM_HOST:-10.11.99.1}"
RM_USER="${RM_USER:-root}"

# xochitl document store on the device (relative to $HOME so it works
# regardless of the remote home dir).
RM_XOCHITL_DIR="${RM_XOCHITL_DIR:-.local/share/remarkable/xochitl}"

# Fake-xochitl mode: when XOCHITL_DIR is set, push.sh copies the fileset into
# that local directory instead of ssh-ing anywhere, and skips systemctl.
# (Leave unset for real device pushes.)

# Name shown in the tablet's document list.
VISIBLE_NAME="${VISIBLE_NAME:-gv spike 0}"

die() {
    echo "error: $*" >&2
    exit 1
}
