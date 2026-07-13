#!/usr/bin/env bash
# Render the dummy PDF with a visible generation counter + timestamp.
#
#   ./render_dummy.sh          # increment stored counter and render
#   ./render_dummy.sh 7        # render a specific generation number
#
# Uses typst when installed; otherwise falls back to a dependency-free
# minimal-PDF writer (python3 stdlib only). Output: $OUT_DIR/dummy.pdf.
# The current generation number is persisted in $OUT_DIR/counter.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

mkdir -p "$OUT_DIR"

if [ $# -ge 1 ]; then
    counter="$1"
else
    counter=$(( $(cat "$OUT_DIR/counter" 2>/dev/null || echo 0) + 1 ))
fi
timestamp="$(date '+%Y-%m-%d %H:%M:%S %Z')"
pdf="$OUT_DIR/dummy.pdf"

# Page size: reMarkable 2 screen is 1404x1872 px at 226 DPI = 447.3x596.5 pt.
if command -v typst >/dev/null 2>&1 && [ "${FORCE_MINIMAL_PDF:-0}" != "1" ]; then
    typ="$OUT_DIR/dummy.typ"
    cat > "$typ" <<EOF
#set page(width: 447.3pt, height: 596.5pt, margin: 40pt)
#set text(size: 16pt)
= gv-remarkable spike 0
#v(2cm)
#text(size: 44pt, weight: "bold")[generation $counter]
#v(1cm)
rendered $timestamp
EOF
    typst compile "$typ" "$pdf"
else
    COUNTER="$counter" TS="$timestamp" OUT="$pdf" python3 - <<'EOF'
import os

counter, ts, out = os.environ["COUNTER"], os.environ["TS"], os.environ["OUT"]
W, H = 447.3, 596.5

def esc(s):
    return s.replace("\\", r"\\").replace("(", r"\(").replace(")", r"\)")

lines = [
    ("gv-remarkable spike 0", 20, H - 70),
    ("generation %s" % counter, 44, H - 170),
    ("rendered %s" % ts, 14, H - 230),
]
stream = "".join(
    "BT /F1 %d Tf 40 %.1f Td (%s) Tj ET\n" % (size, y, esc(text))
    for text, size, y in lines
).encode()

objs = [
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    (
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.1f %.1f] "
        "/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>" % (W, H)
    ).encode(),
    b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"endstream",
]

buf = b"%PDF-1.4\n"
offsets = []
for i, obj in enumerate(objs, 1):
    offsets.append(len(buf))
    buf += b"%d 0 obj\n" % i + obj + b"\nendobj\n"
xref = len(buf)
buf += b"xref\n0 %d\n" % (len(objs) + 1) + b"0000000000 65535 f \n"
for off in offsets:
    buf += b"%010d 00000 n \n" % off
buf += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (
    len(objs) + 1, xref)

with open(out, "wb") as f:
    f.write(buf)
EOF
fi

echo "$counter" > "$OUT_DIR/counter"
echo "rendered generation $counter ($timestamp) -> $pdf"
