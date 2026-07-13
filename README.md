# gv-remarkable

reMarkable 2 surface plugin for [grove](https://github.com/JollyGrin/grove) (`gv`):
a live, in-place-refreshed fleet status document, long-form findings rendered for
e-ink reading, and (eventually) handwritten answers steering orchestrators.

A **surface plugin** in grove's sense: a standalone sidecar that consumes the
public contract — polls `gv <cmd> --json`, tails `events.jsonl`, steers only via
`gv answer`/`gv nudge` — and never touches grove internals. See grove issues
[#75](https://github.com/JollyGrin/grove/issues/75) (surface-plugin contract) and
[#76](https://github.com/JollyGrin/grove/issues/76) (this plugin's design ticket).

## Status

Pre-implementation. Current work: **Spike 0** — prove the SSH transport with a
dummy document (push a xochitl fileset, overwrite the same UUID in place, verify
identity/position survive). Scope and acceptance criteria live in
[grove#76's Spike 0 comment](https://github.com/JollyGrin/grove/issues/76).
The scaffold lives in [`spike/`](spike/README.md): run `spike/test.sh`
locally (no device), then follow [`spike/RUNBOOK.md`](spike/RUNBOOK.md) for
the live tablet test.

## Design (from grove#76)

- **Transport**: vanilla `ssh`/`scp`/`systemctl restart xochitl` over USB or
  Tailscale. No Toltec, nothing installed on the tablet. Cloud (`rmapi`) only as
  a fallback; `rmfakecloud` is a possible later spike.
- **Rendering**: markdown → Typst → PDF at 1404×1872 px / 226 DPI. No EPUB.
- **Read-back**: `.rm` v6 strokes via rmscene/rmc → PNG → Claude vision;
  confirm-checkbox = geometric hit-test on a known template.
- **Phases**: M1 read-only status doc → M2 long-form reading → M3 handwritten
  steering (relay-class commands only, on-paper confirm required).

## Guardrails

All mutations go through `gv` commands; propose-then-dispose — nothing reaches a
worker without an explicit human confirmation mark; the status document is a
read-only projection, never authoritative.
