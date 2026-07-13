# Spike 0 findings

Two parts: what the worker verified locally (done), and the device-test
template for the operator to fill in and post back on
[issue #1](https://github.com/JollyGrin/gv-remarkable/issues/1).

## Verified locally (fake-xochitl mode, no device)

- `./test.sh` green: fileset well-formed (valid JSON `.metadata`/`.content`,
  PDF magic, non-empty `.pagedata`), UUID stable across 3 update cycles,
  never more than one document in the store, stale `*.thumbnails` caches
  purged on every push, `lastModified` monotonic epoch-ms.
- Design decisions worth carrying into M1:
  - **Stop → copy → start** rather than copy-then-restart: xochitl flushes
    in-memory metadata on exit and can clobber files copied while it runs.
  - **Cache purge** (`<uuid>.cache`, `<uuid>.thumbnails`) on every push, or
    the tablet may show a stale thumbnail of the previous generation.
  - **`scp -O`** auto-detection: OpenSSH ≥ 9 defaults to SFTP, which the
    tablet's dropbear doesn't serve.
  - Legacy-style `.content` JSON (per adaerr/pdf2remarkable) — known to be
    accepted by 3.x firmware; device test confirms.

## Device test results (operator: fill in)

| item | result |
|---|---|
| Firmware version (Settings → General → Software) | _…_ |
| `/etc/version` build id | _…_ |
| Transport(s) tested | USB / WiFi / Tailscale |
| Document appeared after first push | yes / no |
| In-place update cycles run | _n_ (≥3) |
| Duplicate ever created | yes / no |
| Content refreshed (no stale thumbnail) | yes / no |
| Restart blip, script stop→start | _…_ s |
| Restart blip, total until UI redrawn | _…_ s |
| List position after update (default `lastModified`) | stayed / moved to top / other |
| List position with `LAST_MODIFIED_MS` pinned | _…_ / not tested |
| Update while document open on tablet | _behavior…_ / not tested |
| Quirks / surprises | _…_ |

## Draft comment for issue #1 (operator: edit values, then post)

```markdown
Ran the Spike 0 device test on a reMarkable 2, firmware **X.Y.Z.NNNN**
(`/etc/version`: NNNN), over **USB (10.11.99.1)** [and WiFi].

**Verdict: in-place update works / does not work.**

- Initial `push.sh`: document "gv spike 0" appeared once in My Files.
- N × `update.sh`: same document refreshed in place each time — generation
  counter advanced 1→N+1, no duplicate ever created, no stale thumbnail.
- Restart blip: ~Ns script-side (stop→start), ~Ms until the UI was fully
  redrawn. Consistent across cycles.
- List position: [stayed put / jumped to top of default sort since each push
  bumps `lastModified`; pinning `LAST_MODIFIED_MS` kept it in place].
- Updating while the document was open: [behavior].
- Quirks: [none / …].

Scaffold used: `spike/` at <commit>. Key auth via `ssh-copy-id`; no password
stored anywhere; nothing installed on the tablet.
```
