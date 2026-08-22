# 04 — Troubleshooting: every failure mode hit during this project

Each entry: **Symptom → Root cause → Fix**. All of these actually occurred.

---

## 1. Print jobs hang in "processing" forever (Canon driver)

- **Symptom**: `lpstat` shows `now printing` for minutes; log shows endless
  `Wrote 81 bytes / Read 81 bytes` pairs; no paper.
- **Cause**: Canon driver 16.91 deadlocks on Tahoe — see [01-DIAGNOSIS.md](01-DIAGNOSIS.md).
- **Fix**: none possible inside that stack; use the G2010IPP pipeline.

## 2. Jobs marked "completed" but printer silent

- **Symptom**: CUPS history says `job-completed-successfully`; nothing fed.
- **Cause**: same handshake stall ending in a benign exit; completion is
  scheduler-side only.
- **Fix**: same as #1.

## 3. After power-cycling the printer, device ID comes back empty

- **Symptom**: error_log shows
  `Returning CUPS_SC_STATUS_OK with 0 bytes ()…`, all subsequent jobs fail fast
  or hang.
- **Cause**: a backend process from *before* the replug survived and kept a dead
  USB handle; the re-enumerated device has a new IORegistry node.
- **Fix**:
  ```bash
  cancel -a                      # kill jobs → their backends die
  pkill -f "cups/backend/usb"    # belt & braces
  lp file.pdf                    # fresh job spawns a fresh backend
  ```

## 4. Pipeline receives `.urf` instead of PDF ("Can't open …_stdin_.urf")

- **Symptom**: `/tmp/g2010_cg.log`: `ERROR: Can't open ".../spool_ipp/1-_stdin_.urf."`,
  USB log shows `Sent 0 bytes`.
- **Cause**: driverless (`-m everywhere`) queues convert to Apple Raster unless
  the server advertises PDF.
- **Fix**: start `ippeveprinter` with `-f application/pdf`, then recreate the
  system queue so it refreshes capability cache:
  ```bash
  lpadmin -x G2010IPP && \
  lpadmin -p G2010IPP -E -v "ipp://localhost:8632/ipp/print" -m everywhere
  ```

## 5. System queue can't execute our filter ("Invalid argument")

- **Symptom**: `Unable to start filter "/Users/…/rastertogutenprint.5.3" -
  Invalid argument.` Binary runs perfectly standalone; `codesign -vv` valid.
- **Cause**: Apple's cupsd sandbox restricts filter execution to its ServerBin
  and `/Library/Printers/**`. Both root-owned; `/usr/local` not admin-writable.
- **Fix**: architectural — don't put user filters in system queues. That's why
  the IPP-server design exists ([02-ARCHITECTURE.md](02-ARCHITECTURE.md)).

## 6. "Insecure permissions" warning about a filter in Printer settings

- **Symptom**: `File "…" has insecure permissions (0100755/uid=501/gid=20)`
  attached to a queue; looks like a "repair permissions" request.
- **Cause**: a queue whose PPD points at a user-owned filter binary. The print
  system treats non-root-owned filters as a security risk.
- **Fix**: delete such queues (`lpadmin -x NAME`). The working G2010IPP route
  never exposes user filters to the system scheduler.

## 7. LaunchAgent death spiral (`EX_CONFIG`, repeated runs)

- **Symptom**: `launchctl print gui/$UID/com.foozio.g2010.printserver` shows
  `runs = 844, last exit code = 78: EX_CONFIG`; later even trivial test agents
  fail to bootstrap (`Input/output error`); server won't auto-start.
- **Cause**: the old Desktop command and the `KeepAlive` LaunchAgent both owned
  process startup. After a restart, they raced for port 8632; the loser exited
  with `EX_CONFIG`, and repeated launchd failures left no working listener.
- **Fix**:
  ```bash
  ~/Downloads/Codes/g2010i/harness/printserver-control.sh restart
  ```
  The controller atomically unloads the job, removes only a verified orphaned
  `ippeveprinter`, installs the checked-in LaunchAgent, reloads it, and waits
  for port 8632. The Desktop command invokes this same path, so there is only
  one process owner. If macOS asks, allow the item under *System Settings →
  General → Login Items & Extensions*.

## 8. Canon IJ Printer Utility hangs at "Please wait"

- **Symptom**: Nozzle Check / maintenance shows an endless wait; no mechanics.
- **Cause**: maintenance commands ride the same gated Canon path (#1).
- **Fix**: avoid on this OS. Use the printer's physical button combos or a
  Windows VM for head cleaning.

## 9. Homebrew gutenprint cask unusable

- **Symptom**: `brew install --cask gutenprint` → disabled 2025-10-14
  (discontinued upstream), and SourceForge blocks scripted downloads of the DMG.
- **Fix**: build from SourceForge git tag — [06-BUILD-NOTES.md](06-BUILD-NOTES.md).

## 10. Gutenprint build failures

| Error | Fix |
|---|---|
| `autogen.sh` exits 1 (Apple `libtool --version` conflict, missing `glib-mkenums`) | autoreconf already succeeded by then — skip autogen, run `./configure` directly |
| `make` dies at `html-stamp` | reconfigure with `--without-doc` |
| `make install` fails writing `/usr/libexec/cups/backend/…` | pass overrides `cupsexec_backenddir= cupsexec_driverdir= cupsexec_filterdir=$HOME/gp/cupsexec/filter`; the final chmod-hook error on the old path is harmless |

Full reproduction: [06-BUILD-NOTES.md](06-BUILD-NOTES.md).

## 11. Two printers appear / wrong one selected

Keep exactly one system queue: **G2010IPP**. Delete strays:

```bash
lpstat -v                       # list queues
lpadmin -x <name>               # remove unwanted
lpoptions -d G2010IPP           # set default
```
