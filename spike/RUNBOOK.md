# Device runbook — Spike 0 live test

Operator instructions for running the in-place update proof against a real
reMarkable 2. Everything runs from your computer in the `spike/` directory;
nothing is installed on the tablet.

> **Safety**: the scripts only ever write four files named
> `deadbeef-cafe-4000-8000-5eed5eed0001.*` into the xochitl folder and
> restart the UI. They never touch other documents, never install anything,
> and never modify system files. Worst case is deleting those four files
> (`./cleanup.sh`) and restarting the tablet.

## 0. Prerequisites

- reMarkable 2 with its USB cable (recommended for the first run), or on the
  same WiFi/Tailscale network as your computer.
- `ssh`, `scp` on your computer (macOS/Linux: already there), plus `python3`
  **or** `typst` for rendering.
- Record your firmware version now: on the tablet, **Settings → General →
  Software** — you'll paste it into `FINDINGS.md`. (Fw > 3.3.2.1666 note:
  this spike installs nothing, so the Toltec/soft-brick warnings don't apply;
  we use only stock ssh + systemctl.)

## 1. One-time: SSH access with a key (password typed once, stored nowhere)

1. On the tablet find the SSH credentials: **Settings → General → Help →
   Copyrights and licenses** (on some firmware: **Settings → Help → About →
   Copyrights and licenses**). Scroll to the bottom of the *GPLv3
   Compliance* section: it shows the addresses the device listens on and the
   **root password**. Leave this screen open.
2. Plug in the USB cable. The tablet appears as a USB network device at
   `10.11.99.1`.
3. If you don't already have an SSH key: `ssh-keygen -t ed25519` (accept the
   defaults).
4. Copy your key to the tablet — **this is the only time the password is
   ever typed, and it goes straight to `ssh`, never into a file**:

   ```sh
   ssh-copy-id root@10.11.99.1
   ```

   Type the password from step 1 when prompted.
5. Verify passwordless login works:

   ```sh
   ssh -o BatchMode=yes root@10.11.99.1 'echo ok; cat /etc/version'
   ```

   Should print `ok` and a build number (record it alongside the firmware
   version). If it still asks for a password, key auth didn't take — see
   Troubleshooting.

   The push scripts use `BatchMode=yes` throughout, so they are *incapable*
   of prompting for or handling a password.

> **Note**: a factory reset or (on some versions) a firmware update can wipe
> `authorized_keys` and/or rotate the root password — just redo this section
> if pushes suddenly ask for auth.

### USB vs WiFi/Tailscale

| transport | host | notes |
|---|---|---|
| USB cable | `10.11.99.1` (the default) | most reliable; works even if WiFi is off |
| WiFi | LAN IP shown on the Copyrights screen | tablet must be awake; IP may change (DHCP) |
| Tailscale-fronted | your subnet-router / proxy host | only if you've set that up on your side; nothing gets installed on the tablet |

Select with `RM_HOST`, e.g. `RM_HOST=192.168.1.42 ./update.sh`. Repeat
`ssh-copy-id` for each address you plan to use (host key differs per address,
key auth doesn't).

## 2. The live test

All commands from the `spike/` directory. Have a stopwatch (or just count)
for the restart blip.

### 2a. Initial push

```sh
./update.sh          # renders generation 1 and pushes it
```

Watch the tablet. Expected: the screen blanks/freezes briefly while xochitl
restarts (the script prints its stop→start time; the UI takes a few extra
seconds to redraw — **note the total blip duration**), then **My Files**
shows a new document **“gv spike 0”**. Open it: page says `generation 1`
with a render timestamp.

### 2b. In-place updates (run at least 3)

Note the document's position in the My Files list, then:

```sh
./update.sh
```

After the blip, verify **all** of:

- **No new document** — still exactly one “gv spike 0”.
- Opening it shows `generation 2` (then 3, 4, … on each further run) with a
  fresh timestamp — and **not** a stale thumbnail of the old page.
- Its position in the list: with the default sort the entry may jump to the
  top because each push refreshes `lastModified`. That's identity-preserving
  (same document, same UUID) — record what you observe. To pin the timestamp
  instead, try one cycle with:

  ```sh
  LAST_MODIFIED_MS=$(date +%s)000 ./update.sh   # or reuse a fixed value
  ```

- Note the blip duration each cycle (they should be consistent).

Run `./update.sh` twice more. Also worth trying once: update **while the
document is open** on the tablet — note whether xochitl reopens it, returns
to My Files, or misbehaves.

### 2c. WiFi run (optional but useful)

Unplug USB, then `RM_HOST=<wifi-ip> ./update.sh` — confirms the transport
works untethered and lets you compare blip/transfer time.

### 2d. Record results

Fill in `FINDINGS.md` (firmware version, blip durations, list-position
behavior, any quirks) and post its draft comment on issue #1.

### 2e. Cleanup (optional)

```sh
./cleanup.sh         # removes only the dummy document, restarts xochitl
```

## 3. What "success" looks like

- The document appears once and only once, ever, across all cycles.
- Content refreshes in place on every `./update.sh`; identity (UUID, name,
  list entry) is preserved.
- Restart blip is a few seconds and bounded — this is the cost M1 will pay
  per status refresh.

## Troubleshooting

- **`scp` errors mentioning sftp / "subsystem request failed"** — your scp
  defaulted to SFTP, which the tablet doesn't serve. The scripts try
  `scp -O` automatically; if you're running scp by hand, add `-O`.
- **`ssh-copy-id` succeeded but login still asks for a password** — some
  older firmware's dropbear predates ed25519 support. Generate an RSA key
  (`ssh-keygen -t rsa -b 4096`) and `ssh-copy-id -i ~/.ssh/id_rsa.pub root@…`.
- **Host key warning after a device reset** — expected;
  `ssh-keygen -R 10.11.99.1` and reconnect.
- **Document doesn't appear after push** — check for typos on the ssh side:
  `ssh root@10.11.99.1 'ls -la .local/share/remarkable/xochitl/ | grep deadbeef'`
  should list 4 files. If they're there but no document shows, reboot the
  tablet (power button) and report as a quirk.
- **Tablet stuck on a frozen screen** — `ssh root@10.11.99.1 'systemctl start xochitl'`;
  if unreachable, hold the power button ~10s to hard-reboot. No persistent
  harm — the spike changes no system state.
