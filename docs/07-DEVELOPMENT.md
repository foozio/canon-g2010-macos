# 07 — Developer Guide

> Collaboration reference for people working on the code itself. For *using* the
> solution see [`03-OPERATIONS.md`](03-OPERATIONS.md); for the design rationale see
> [`02-ARCHITECTURE.md`](02-ARCHITECTURE.md). Top-level contribution rules live in
> [`../CONTRIBUTING.md`](../CONTRIBUTING.md).

## 1. What you're working on

Two cooperating subsystems plus vendored references:

```
G2010 Manager (SwiftUI app)            Print/Scan runtime (shell + launchd)
┌───────────────────────────┐          ┌──────────────────────────────────────┐
│ MenuBar + Dashboard        │ launchctl│ LaunchAgent (KeepAlive)               │
│ AppState(@Observable)      │ lp*/…   │   → start-printserver.sh              │
│  ├ PrintServerService(actor)────────▶│     → ippeveprinter :8632             │
│  ├ ScanService(actor)      │ scanimage│        -c print-pipeline.sh           │
│  ├ CUPSService             │          │   cgpdftoraster → Gutenprint → usb   │
│  ├ MaintenanceService      │          └──────────────────────────────────────┘
│  ├ LogService              │          Scan: scanimage → SANE pixma → USB
│  └ ShellExecutor           │
│ RuntimeManager (installer) │  regenerates runtime scripts/plist/PPD
└───────────────────────────┘
```

Key invariant: **launchd is the only long-lived process owner.** Nothing else may
spawn or babysit `ippeveprinter`.

## 2. Repository map

| Path | Tracked | What |
|---|---|---|
| `G2010Manager/` | ✅ | SwiftUI app (`Sources/`) + packaging (`packaging/`) |
| `harness/` | ✅ (3 scripts) | lifecycle controller, launcher, print pipeline |
| `launchd/` | ✅ | LaunchAgent plist template |
| `G2010_gutenprint/` | ✅ | generated PPD |
| `tests/` | ✅ | shell lifecycle test suite |
| `docs/` | ✅ | this documentation set |
| `.github/` | ✅ | issue/PR templates + CI workflows |
| `gutenprint-src/` | ❌ ignored | upstream driver source (fetch per doc 06) |
| `cnijfilter2-src/` | ❌ ignored | Canon GPL driver (protocol reference only) |
| `harness/spool*`, `*.log`, `capture/` | ❌ ignored | privacy / ephemera |

⚠️ Two producers write the same runtime files: `harness/printserver-control.sh`
(Gen-1) copies the checked-in scripts, while the Swift `RuntimeManager` (Gen-2)
regenerates them from string templates. If you change one, check the other —
keeping them consistent is a known maintenance burden (the pipeline template in
`RuntimeManager` currently diverges from the tested `harness/print-pipeline.sh`).

## 3. Development environment setup

Prerequisites (Apple Silicon, macOS 14+):

```bash
xcode-select --install
brew install autoconf automake libtool pkg-config   # to build Gutenprint
brew install cups sane-backends libusb              # runtime deps (cups is keg-only)
```

No printer is required to build, run tests, or work on most code.

### Build the Swift app

```bash
cd G2010Manager
swift build                # debug
swift build -c release     # release (what the DMG packages)
.build/debug/G2010Manager  # run it (menu-bar icon appears)
```

The app uses only system frameworks (SwiftUI, AppKit, Foundation, Network) —
please do not add external Swift dependencies.

### Build the Gutenprint driver (only if you change the print path)

Follow [`06-BUILD-NOTES.md`](06-BUILD-NOTES.md) exactly — it installs into
`~/gp` with no sudo. Do **not** use `autogen.sh` (it fails on macOS); run the
generated `./configure` directly.

## 4. Running the tests

```bash
./tests/test-printserver-control.sh
```

- No hardware needed: it fakes `launchctl`, `lsof`, `ps`, `kill`, `sleep` via
  `PATH` overrides and asserts the controller's exact ordering/guard behavior.
- Every shell/runtime change must keep this suite green.
- Add a new fixture-based test in the same style when you change lifecycle logic.

Swift currently has no unit-test target. If you add one, wire it into
`.github/workflows/ci.yml`.

## 5. Common change recipes

### Add support for a sibling printer model (e.g. G1010/G3010)

1. List candidates: `~/gp/sbin/cups-genppd.5.3 -M | grep -i g`.
2. Generate a PPD for the model and set `*cupsFilter` to the absolute filter path
   (see doc 06 §4).
3. The scanner is model-agnostic (`pixma` backend) — only the device serial
   differs. Serials are currently hardcoded in a few places; see §7.

### Change the print pipeline

Edit `harness/print-pipeline.sh` (the tested source of truth) **and** mirror the
change in `RuntimeManager.generatePrintPipelineScript()`. Preserve the
`job-id user title copies options file…` calling convention that `ippeveprinter`
uses. Keep `set -euo pipefail` so an upstream failure is not reported as success.

### Add a panel to the Manager app

1. Add a case to `SidebarItem` in `Views/DashboardView.swift`.
2. Create `Views/<Name>Panel.swift`, reading shared state via
   `@Environment(AppState.self)`.
3. Put new side effects in a service (`Services/`), not the view. Services that
   touch external processes should be `actor`s.

### Change a runtime constant (port, queue name, label)

These values are duplicated across Swift and shell. Today you must update every
occurrence — grep first:

```bash
grep -rn "8632\|G2010IPP\|com.foozio.g2010.printserver\|0C7A8F" \
  G2010Manager/Sources harness launchd G2010-PrintServer.command
```

## 6. Debugging

| Symptom | Where to look |
|---|---|
| Server not starting | `~/Library/Logs/G2010PrintServer.log`, `launchctl print gui/$(id -u)/com.foozio.g2010.printserver` |
| Job fails mid-pipeline | `/tmp/g2010_cg.log`, `/tmp/g2010_gp.log`, `/tmp/g2010_usb.log` |
| Port conflict / orphan | `lsof -nP -iTCP:8632 -sTCP:LISTEN` |
| Scanner not found | `scanimage -L` (with `SANE_CONFIG_DIR`/`DYLD_LIBRARY_PATH` set as in `RuntimeManager.scanEnvironment`) |
| Dylib load errors in the DMG build | `otool -L <binary>` — every path must be `@executable_path/…` or `@loader_path/…` |

Reset everything to a known state: `harness/printserver-control.sh restart`.

## 7. Known sharp edges (fix welcome — see issue tracker)

- Printer serial `0C7A8F` and some `/Users/foozio` paths are hardcoded in places;
  move toward runtime discovery / `$HOME`.
- The Swift `RuntimeManager`-generated `print-pipeline.sh` mis-parses the
  ippeveprinter argument convention; prefer copying the tested harness script.
- The IPP listener should be confirmed loopback-only for multi-host networks.
- No Swift unit tests yet.

## 8. Style & conventions

- **Shell:** `#!/bin/bash`, `set -euo pipefail`, quote expansions, overridable
  `PRINTSERVER_*` env knobs in the controller.
- **Swift:** Swift API design guidelines; `actor` for external-process services;
  `@Observable` for UI state; no third-party dependencies.
- **Docs:** numbered files under `docs/`; keep them in sync when behavior changes.

## 9. CI & release

- `.github/workflows/ci.yml` — on every push/PR: bash syntax check, plist lint,
  shell lifecycle tests, Swift debug+release build (macOS 15 runners, no hardware).
- `.github/workflows/release.yml` — on `v*` tags: builds Gutenprint from source,
  runs the tests, builds the self-contained DMG, and attaches it to the GitHub
  release. DMGs are ad-hoc signed; using a Developer ID + notarization requires
  repository secrets (maintainers only).

## 10. Checklist before opening a PR

1. `./tests/test-printserver-control.sh` passes.
2. `cd G2010Manager && swift build` passes (CI will also check release build).
3. `bash -n` on any shell script you touched; `plutil -lint` on any plist.
4. No vendored trees, spool, logs, or documents staged (`git status` clean of them).
5. Docs updated if behavior changed.
6. Filled in the PR template, including how you tested and whether real hardware
   was involved.
