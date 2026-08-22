# Canon PIXMA G2010 on Apple Silicon macOS (Tahoe 26) — Complete Solution

> **Status: WORKING — Print ✅ Scan ✅**
> Built 2026-08-22 · macOS 26.6.1 (25G76) · arm64 · Zero Canon-macOS-driver involvement

This project makes a USB-only Canon PIXMA G2010 fully work on modern macOS after
Canon's own driver proved defective on this OS. It combines Apple's stock CUPS
tools, a natively-built open-source Gutenprint driver, and a tiny userspace IPP
server — **no sudo required for operation**, no kernel extensions, no hacks.

---

## Quick start

| Task | How |
|---|---|
| **Print** | Any app → choose printer **G2010IPP** (system default). CLI: `lp file.pdf` |
| **Scan** | `scanimage -d "pixma:04A9183A_0C7A8F" --format=png --resolution 300 > out.png` |
| **Server down?** | Double-click **`G2010-PrintServer.command`**; it safely resets the launchd-owned server |

## Documentation index

| Doc | Contents |
|---|---|
| [`docs/01-DIAGNOSIS.md`](docs/01-DIAGNOSIS.md) | Why Canon's official driver fails on Tahoe — full evidence trail |
| [`docs/02-ARCHITECTURE.md`](docs/02-ARCHITECTURE.md) | The working solution: design, data flow, component inventory |
| [`docs/03-OPERATIONS.md`](docs/03-OPERATIONS.md) | Daily usage, service control, logs, post-reboot checklist |
| [`docs/04-TROUBLESHOOTING.md`](docs/04-TROUBLESHOOTING.md) | Every failure mode encountered during the build-out, symptom → cause → fix |
| [`docs/05-PROTOCOL-NOTES.md`](docs/05-PROTOCOL-NOTES.md) | Reverse engineering: Canon IVEC/XML-over-USB protocol, device topology |
| [`docs/06-BUILD-NOTES.md`](docs/06-BUILD-NOTES.md) | Reproduce: rebuild Gutenprint from source exactly as done here |

## One-paragraph summary

Canon's G2000-series macOS driver (≤16.91) deadlocks on macOS 26: it queries the
printer's condition (`STA:10`, "ink status unknown"), tries to show an
acknowledgment dialog that never renders, and loops tiny status packets forever
without ever sending page data. The fix bypasses Canon's Mac stack entirely:
a **Gutenprint 5.3.3 driver compiled natively for arm64** converts CUPS raster to
Canon's printer language, chained behind **Apple's own PDF rasterizer and USB
backend**, fronted by **`ippeveprinter`** (standalone IPP server) that the normal
macOS print dialog talks to like any AirPrint printer. Scanning goes through
**SANE's pixma backend**, which speaks Canon's scanner protocol independently.

## Repository layout

```
g2010i/
├── README.md                  ← you are here
├── docs/                      ← the six documents above
├── harness/
│   ├── printserver-control.sh ← installs/resets the launchd-owned runtime
│   ├── start-printserver.sh   ← env-safe runtime launcher template
│   ├── print-pipeline.sh      ← PDF → raster → Canon stream → USB
│   └── etc/,log/,…            ← abandoned private-cupsd experiment (kept for reference)
├── launchd/                   ← checked-in LaunchAgent template
├── G2010_gutenprint/
│   └── stp-bjc-G2000-series.5.3.ppd   ← our PPD (cupsFilter points at ~/gp filter)
├── gutenprint-src/            ← Gutenprint 5_3_3 source tree (built into ~/gp)
├── cnijfilter2-src/           ← Canon's GPL Linux driver (protocol ground truth)
├── capture/                   ← offline experiments, original PPD backup
├── usb_tree.txt               ← IORegistry dump of the printer
└── scan_test.png              ← first successful scan (proof artifact)
```

## External runtime dependencies (Homebrew)

`sane-backends` · `cups` (keg-only: provides `ippeveprinter`) · `libusb`

Build-time only: `autoconf automake libtool pkg-config`

The installed runtime lives outside the privacy-protected Downloads folder at
`~/Library/Application Support/G2010PrintServer`; launchd logs to
`~/Library/Logs/G2010PrintServer.log`.
