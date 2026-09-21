# 03 — Operations guide

## Printing

The system default printer is **G2010IPP**. Print from any app as usual.

```bash
lp file.pdf                 # default queue
lp -d G2010IPP doc.pdf      # explicit
lpstat -o                   # see queue
cancel -a G2010IPP          # purge jobs
```

Notes:
- First print after rebooting **the printer** may pause a few seconds while the
  USB backend re-opens the device.
- Media size/type follow the PPD defaults (A4, plain). Change per-job with
  `lp -o media=A4 -o …` or in the app dialog.

## Scanning

```bash
# list devices (should show pixma:04A9183A_0C7A8F)
scanimage -L

# basic A4 scan → PNG
scanimage -d "pixma:04A9183A_0C7A8F" --format=png --resolution 300 > out.png

# batch of N pages from the flatbed
for i in 1 2 3; do scanimage -d "pixma:04A9183A_0C7A8F" --format=png > page$i.png; done
```

Resolution up to 600 dpi is supported by the hardware. The first scan after the
printer wakes from sleep may need one retry.

## The print server

One launchd-owned instance of `ippeveprinter` must be running for printing to
work. Do not start `ippeveprinter` or `start-printserver.sh` independently;
doing so creates competing owners for port 8632.

**Start / restart:**

```bash
# Double-click on Desktop, or run the same controller in Terminal:
G2010-PrintServer.command
~/Downloads/Codes/g2010i/harness/printserver-control.sh restart
```

**Verify it's alive:**

```bash
lsof -iTCP:8632 -sTCP:LISTEN        # expect ippeveprinter LISTENing
pgrep -fl ippeveprinter
~/Downloads/Codes/g2010i/harness/printserver-control.sh status
```

**Verify the bind scope (loopback vs LAN):**

```bash
lsof -nP -iTCP:8632 -sTCP:LISTEN    # read the NAME column
```

`ippeveprinter` (CUPS 2.4.x) has no listen-address option: expect `*:8632`
(all interfaces, IPv4+IPv6) with no authentication. That means anyone on your
local network can reach the print server — fine at home, beware on café/office
Wi-Fi. `printserver-control.sh status` prints the scope (`Listening on:`);
`restart` warns on stderr when it is not loopback-only. On untrusted networks,
turn on the macOS firewall (System Settings → Network → Firewall). Never
port-forward 8632 on your router.

## Logs

| Log | Path | Shows |
|---|---|---|
| IPP server | `~/Library/Logs/G2010PrintServer.log` | launchd startup, job submissions, client errors |
| PDF rasterizer | `/tmp/g2010_cg.<jobid>.log` (latest via `/tmp/g2010_cg.log`) | cgpdftoraster stage |
| Gutenprint filter | `/tmp/g2010_gp.<jobid>.log` (latest via `/tmp/g2010_gp.log`) | conversion detail, errors |
| USB backend | `/tmp/g2010_usb.<jobid>.log` (latest via `/tmp/g2010_usb.log`) | device open/write/back-channel |
| System scheduler | `/var/log/cups/error_log` | system queue side |

## Spool, logs & retention (privacy)

The spool holds your full document bytes, and logs echo job titles and
usernames. Protections in place (TASK-003):

- Runtime + spool dirs are `0700`, spool files and the server log are `0600`
  (new files are born owner-only via `umask 077` in the launcher; each
  `restart` re-tightens pre-existing files).
- Every `restart` deletes spool files older than 3 days
  (`PRINTSERVER_SPOOL_MAX_AGE_DAYS` overrides; young/in-flight jobs survive).
- At-rest secrecy beyond DAC relies on FileVault — keep it enabled.
- Scan outputs (`Scan_<timestamp>.<ext>`) are ordinary user files wherever
  you save them; retention is yours to manage.
- Stage logs are per-job (`/tmp/g2010_<stage>.<jobid>.log`); the fixed
  `/tmp/g2010_<stage>.log` paths symlink to the latest job. The server log
  rotates at 5 MB on `restart` (one `.1` backup); the in-app console follows
  the rotation automatically.

## Post-reboot checklist

1. Printer powered on, USB cable connected.
2. Server running? `printserver-control.sh status`
   - If **yes** → done.
   - If **no**: double-click `G2010-PrintServer.command`; it unloads stale
     launchd state, removes only a verified orphan, and reloads one owner.
3. Test: `echo hello | lp`, watch paper.
4. If System Settings shows a stale/duplicate printer, remove it; keep only
   **G2010IPP**. Re-add if needed:
   ```bash
   lpadmin -x G2010IPP
   lpadmin -p G2010IPP -E -v "ipp://localhost:8632/ipp/print" -m everywhere
   lpoptions -d G2010IPP
   ```

## What NOT to use anymore

- The Canon "G2000 series" driver queues (`Canon_G2010`) — deadlocked by design
  on this OS; they were removed. Re-adding them will only reproduce the bug.
- Canon IJ Printer Utility maintenance buttons — they hang at "Please wait".
  Head cleaning etc. can be triggered from Windows/a VM if ever needed, or via
  the printer's own button combos.
- Note on the Manager's own Maintenance panel: it sends BJL commands directly
  over the Apple USB backend (not through Canon's utility), gated on server /
  queue / idle state with Deep Cleaning behind a confirmation, and backend
  failures now surface as errors. A reported success means the backend
  *accepted* the command — mechanical effect on this firmware (`VER:1.040`)
  is still unverified, so prefer the printer's button combos for critical
  maintenance until someone confirms otherwise.
