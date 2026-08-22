# 01 — Diagnosis: why Canon's official driver fails on macOS Tahoe 26

*Investigation date: 2026-08-22. All evidence collected live on the affected machine.*

## Environment

| Item | Value |
|---|---|
| OS | macOS Tahoe **26.6.1**, build 25G76, arm64 (Apple M-series) |
| Printer | Canon PIXMA G2010 series — USB only (no network) |
| USB identity | VID `0x04A9` PID `0x183A`, serial `0C7A8F`, USB 2.0 Hi-Speed |
| Firmware | `VER:1.040` (bcdDevice 260) |
| Installed driver | G2000 series CUPS driver **16.91.0.0** (receipt `jp.co.canon.pkg.G2000-169100`, installed 2026-03-29; earlier 16.90 receipt from 2025-11-23) |
| Scanner driver | Canon ICA `IJScanner15f` + Scan Utility installed |
| Queue | `Canon_G2010` → `usb://Canon/G2010%20series?serial=0C7A8F`, idle/enabled |

## Symptoms reported by user

1. Print jobs never print. No paper ever feeds.
2. Scanning also did not work through normal apps.
3. No error dialogs ever appeared.

## Evidence trail (chronological)

### E1 — The pipeline runs, but no data flows
Submitting a test page produced job state `processing → job-printing` with the
Canon filter (`Raster2CanonIJS`) alive and polling cupsd ~once per second.
The Apple `usb` backend logged symmetric **81-byte write / read** exchanges —
status handshakes, not page data. A one-line text page rasterizes to ~216 MB of
CUPS raster; total bytes actually written to the device before stalling: **162**.

### E2 — The printer answers every query
Back-channel reads (`512/216-byte chunks`) flowed continuously during jobs, and
the IEEE-1284 device ID came back complete over the side-channel:

```
SERN:0C7A8F;MFG:Canon;CMD:BJRaster3,IVEC;MDL:G2010 series;CLS:PRINTER;
DES:Canon G2010 series;VER:1.040;STA:10;PSE:KLHP82489;CID:CA_BJR520_IJP;
```

USB communication is bidirectional and healthy.

### E3 — The queue registers ink-condition alerts on every fresh attempt
Regardless of reinstall or queue rebuild:

```
com.canon.ijprinter-ink-job-0
com.canon.ijprinter-ink-indicator-on
com.canon.ijprinter-ink-num-0
com.canon.ijprinter-eid-job-0
com.canon.ijprinter-eid-low-0-out-0-unknown-0
```

The driver derives an "ink unknown / attention" condition from the printer's
responses and never clears it.

### E4 — User-visible history matched the pattern
Jobs 7–11 were canceled by the user after hanging in processing. Job 12 (a
nozzle-check script) reached *completed successfully* **without a single sheet
feeding** — CUPS-level success, physical silence.

### E5 — Driver version ruled out as insufficient cause
Canon's changelog for **16.91.0.0 (2026-03-10)** states:
> "Resolved a display issue occurring on macOS 26."

The user already had 16.91 since March 2026 — and still hit the stall. The bug
class is confirmed by Canon ("display issue" = status dialog cannot render),
but the fix does not cover this deadlock path.

### E6 — Hardware exonerated twice over
- Indicator lights steady/normal, paper loaded, cover closed, printer previously
  primed and printed elsewhere.
- **Power cycle** (off + unplugged 60 s) changed nothing.
- **Canon's own maintenance utility hung identically**: Nozzle Check showed
  *"Printing test page. Please wait."* forever with zero mechanical activity —
  even the simple `@TESTPRINT=…` maintenance command never executes.
- Decisive control experiment: **SANE's pixma backend** drove the same USB
  interfaces with its own independent implementation and completed a full scan
  in 13.7 s (A4, 150 dpi). The device's command processor is fine.

### E7 — Offline filter experiments corroborate a handshake gate
Running `Raster2CanonIJS` outside cupsd: it SIGSEGVs without a back-channel
descriptor (FD3), hangs with a silent back-channel, and polls the print queue's
IPP attributes continuously — consistent with waiting for a condition that the
printer's status stream (per the driver) never satisfies.

## Root cause (conclusion)

> Canon's G2000-series macOS driver gates the start-of-job sequence on an
> ink/status acknowledgment derived from the printer's `STA:10` /
> "ink unknown" report. On macOS 26 the confirmation UI cannot display
> (the exact class of defect Canon's own 16.91 release notes acknowledge),
> so every job — document *and* maintenance — waits forever at the handshake
> and page raster data is never transmitted.

Consequence: **unfixable from outside the closed binary.** The correct move is
to bypass the Canon Mac stack for printing while keeping the hardware (which is
healthy), which is what [`02-ARCHITECTURE.md`](02-ARCHITECTURE.md) describes.
Scanning was solved independently via SANE — see [`03-OPERATIONS.md`](03-OPERATIONS.md).
