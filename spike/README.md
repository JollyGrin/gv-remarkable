# Spike 0 — SSH transport scaffold

Proves the in-place update mechanism for a reMarkable 2: push a PDF as a
proper xochitl fileset over SSH, then overwrite the *same* document (fixed
UUID) with new content — no duplicate, identity and list entry preserved.

Issue: [gv-remarkable#1](https://github.com/JollyGrin/gv-remarkable/issues/1)
· parent design [grove#76](https://github.com/JollyGrin/grove/issues/76).

## Files

| file | purpose |
|---|---|
| `render_dummy.sh` | render `out/dummy.pdf` with generation counter + timestamp (typst if installed, else built-in minimal-PDF writer via python3) |
| `push.sh` | build the 4-file xochitl fileset for the fixed UUID and deliver it (device over ssh/scp, or local dir in fake mode) |
| `update.sh` | the refresh loop: `render_dummy.sh` (counter+1) + `push.sh` |
| `test.sh` | fake-xochitl end-to-end assertions — run this locally, no device needed |
| `cleanup.sh` | remove the dummy document from the device |
| `lib.sh` | shared config (sourced by the others) |
| `RUNBOOK.md` | operator instructions for the live device test |
| `FINDINGS.md` | results template + draft comment to post back on issue #1 |

## Quick start

```sh
./test.sh                         # local, no device: must be ALL GREEN
```

Device (see RUNBOOK.md for one-time SSH key setup first):

```sh
./update.sh                       # render + push over USB (10.11.99.1)
RM_HOST=remarkable ./update.sh    # or via WiFi/Tailscale hostname
```

## Environment variables

| var | default | meaning |
|---|---|---|
| `RM_HOST` | `10.11.99.1` | device address (USB gadget IP, or WiFi/Tailscale host) |
| `RM_USER` | `root` | device SSH user |
| `RM_UUID` | fixed `deadbeef-…0001` | document UUID; never changes across updates |
| `XOCHITL_DIR` | unset | set to a local dir for fake-xochitl mode (no ssh) |
| `OUT_DIR` | `spike/out` | render output + generation counter |
| `VISIBLE_NAME` | `gv spike 0` | document name in the tablet UI |
| `LAST_MODIFIED_MS` | now | override metadata `lastModified` (list-position experiment, see RUNBOOK) |
| `FORCE_MINIMAL_PDF` | `0` | set `1` to skip typst and use the built-in PDF writer |

## Constraints honored

Vanilla `ssh`/`scp`/`systemctl` only — nothing is installed on the tablet, no
Toltec. The scripts stop xochitl **before** copying and start it after
(rationale in `push.sh` header). SSH runs with `BatchMode=yes`: it never
prompts for, stores, or logs a password — key auth is set up once via
`ssh-copy-id` (RUNBOOK step 1).
