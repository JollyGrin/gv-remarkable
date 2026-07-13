#!/usr/bin/env bash
# Fake-xochitl end-to-end test: runs the full render/push/update flow against
# a local temp dir and asserts the fileset is well-formed, the UUID stays
# stable across >=3 update cycles, and no duplicate document is ever created.
# No device, no network. Exit 0 = green.
set -euo pipefail
spike_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export XOCHITL_DIR="$work/xochitl"
export OUT_DIR="$work/out"
source "$spike_dir/lib.sh"

failures=0
pass() { printf '  \033[32mPASS\033[0m %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; failures=$((failures + 1)); }
check() { # check <description> <command...>
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi
}

json_field() { # json_field <file> <key> — prints the value or fails
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$1" "$2"
}

uuids_in_store() {
    find "$XOCHITL_DIR" -mindepth 1 -maxdepth 1 -exec basename {} \; \
        | sed 's/\..*$//' | sort -u
}

echo "== initial push =="
"$spike_dir/render_dummy.sh" >/dev/null
"$spike_dir/push.sh" >/dev/null

for ext in pdf metadata content pagedata; do
    check "$RM_UUID.$ext exists" test -f "$XOCHITL_DIR/$RM_UUID.$ext"
done
check ".metadata is valid JSON" python3 -m json.tool "$XOCHITL_DIR/$RM_UUID.metadata"
check ".content is valid JSON" python3 -m json.tool "$XOCHITL_DIR/$RM_UUID.content"
check ".pdf has PDF magic" grep -q '^%PDF' "$XOCHITL_DIR/$RM_UUID.pdf"
check ".pagedata is non-empty" test -s "$XOCHITL_DIR/$RM_UUID.pagedata"

[ "$(json_field "$XOCHITL_DIR/$RM_UUID.metadata" type)" = "DocumentType" ] \
    && pass "metadata.type is DocumentType" || fail "metadata.type is DocumentType"
[ "$(json_field "$XOCHITL_DIR/$RM_UUID.metadata" visibleName)" = "$VISIBLE_NAME" ] \
    && pass "metadata.visibleName is '$VISIBLE_NAME'" || fail "metadata.visibleName"
[ "$(json_field "$XOCHITL_DIR/$RM_UUID.content" fileType)" = "pdf" ] \
    && pass "content.fileType is pdf" || fail "content.fileType is pdf"
[ "$(uuids_in_store)" = "$RM_UUID" ] \
    && pass "store contains exactly one UUID" || fail "store contains exactly one UUID"
[ "$(cat "$OUT_DIR/counter")" = "1" ] \
    && pass "generation counter is 1" || fail "generation counter is 1"

prev_hash="$(cksum "$XOCHITL_DIR/$RM_UUID.pdf")"
prev_mtime="$(json_field "$XOCHITL_DIR/$RM_UUID.metadata" lastModified)"

for gen in 2 3 4; do
    echo "== update cycle -> generation $gen =="
    # Plant a stale render cache; push.sh must purge it so the tablet
    # cannot show an outdated thumbnail of the old content.
    mkdir -p "$XOCHITL_DIR/$RM_UUID.thumbnails"
    touch "$XOCHITL_DIR/$RM_UUID.thumbnails/stale.jpg"

    "$spike_dir/update.sh" >/dev/null

    [ "$(uuids_in_store)" = "$RM_UUID" ] \
        && pass "UUID stable, no duplicate document" || fail "UUID stable, no duplicate document"
    [ "$(find "$XOCHITL_DIR" -maxdepth 1 -name '*.metadata' | wc -l | tr -d ' ')" = "1" ] \
        && pass "exactly one .metadata in store" || fail "exactly one .metadata in store"
    [ "$(cat "$OUT_DIR/counter")" = "$gen" ] \
        && pass "generation counter is $gen" || fail "generation counter is $gen"

    hash="$(cksum "$XOCHITL_DIR/$RM_UUID.pdf")"
    [ "$hash" != "$prev_hash" ] \
        && pass "PDF content changed" || fail "PDF content changed"
    prev_hash="$hash"

    mtime="$(json_field "$XOCHITL_DIR/$RM_UUID.metadata" lastModified)"
    { [[ "$mtime" =~ ^[0-9]+$ ]] && [ "$mtime" -ge "$prev_mtime" ]; } \
        && pass "lastModified is epoch-ms and non-decreasing" \
        || fail "lastModified is epoch-ms and non-decreasing"
    prev_mtime="$mtime"

    check "stale thumbnails purged" test ! -e "$XOCHITL_DIR/$RM_UUID.thumbnails"
    check ".metadata still valid JSON" python3 -m json.tool "$XOCHITL_DIR/$RM_UUID.metadata"
done

echo
if [ "$failures" -eq 0 ]; then
    echo "ALL GREEN — fileset valid, UUID stable across 3 update cycles, no duplicates."
else
    echo "$failures FAILURE(S)"
    exit 1
fi
