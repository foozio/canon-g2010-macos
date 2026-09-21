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
│  ├ PrintServerService ──▶ controller ──▶ ippeveprinter :8632                │
│  ├ ScanService(actor)      │ scanimage│        -c print-pipeline.sh           │
│  ├ CUPSService             │          │   cgpdftoraster → Gutenprint → usb   │
│  ├ MaintenanceService      │          └──────────────────────────────────────┘
│  ├ LogService              │          Scan: scanimage → SANE pixma → USB
│  └ ShellExecutor           │
│ RuntimeManager (installer) │  copies pristine sources + substitutes prefixes
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

✅ One producer rule (TASK-001): `harness/printserver-control.sh`
installs the checked-in scripts verbatim, while the Swift `RuntimeManager`
installs *copies of those same files* with install-prefix substitution only
(see `installLauncherFromSource()` / `installPipelineFromSource()` /
`installLaunchAgentPlist()`). If you change a runtime file, change the
checked-in source — never the installed copy — and keep
`tests/test-runtime-convergence.sh` green; it locks the substitution contract
from both sides.

## 3. Development environment setup

Prerequisites (Apple Silicon, macOS 14+):

```bash
xcode-select --install
brew install autoconf automake libtool pkg-config   # to build Gutenprint
brew install cups sane-backends libusb              # runtime deps (cups is keg-only)
```

Point dev builds at your checkout (required — there is no hardcoded fallback):

```bash
export G2010_REPO_ROOT="$PWD"   # run from the repo root; add to your shell profile
```

No printer is required to build, run tests, or work on most code.

### Build the Swift app

```bash
cd G2010Manager
swift build                # debug
swift build -c release     # release (what the DMG packages)
G2010_REPO_ROOT="$PWD/.." swift test   # unit tests (hermetic, no hardware)
.build/debug/G2010Manager  # run it (menu-bar icon appears)
```

The app uses only system frameworks (SwiftUI, AppKit, Foundation, Network) —
please do not add external Swift dependencies. App logic lives in the
`G2010ManagerCore` library target (same directory, partitioned by excludes in
`Package.swift` — keep the two subsets complementary); `G2010ManagerTests`
covers settings naming, lpstat parsing, pixma extraction, shell execution,
constants coherence, and the provisioning contract.

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

Swift unit tests (`G2010Manager/Tests/`, run via `swift test`, also in CI)
cover the app core without hardware: extend them when you change parsing,
settings, shell execution, constants, or provisioning (pure/static/published
surface first — see `Tests/G2010ManagerTests/` for the pattern).

## 5. Common change recipes

### Add support for a sibling printer model (e.g. G1010/G3010)

1. List candidates: `~/gp/sbin/cups-genppd.5.3 -M | grep -i g`.
2. Generate a PPD for the model and set `*cupsFilter` to the absolute filter path
   (see doc 06 §4).
3. The scanner is model-agnostic (`pixma` backend) — only the device serial
   differs. Serials are currently hardcoded in a few places; see §7.

### Change the print pipeline

Edit `harness/print-pipeline.sh` (the tested source of truth) — nothing else.
`RuntimeManager` copies it verbatim apart from install-prefix substitution
(`GP_FILTER`, `PPD`), and `tests/test-runtime-convergence.sh` fails if the
substitution literals drift. Preserve the
`job-id user title copies options file…` calling convention that `ippeveprinter`
uses (`shift 5`, file last). Do not reintroduce `INPUT_FILE="$1"`-style
parsing — that was the TASK-001 divergence that broke app-installed printing.

### Add a panel to the Manager app

1. Add a case to `SidebarItem` in `Views/DashboardView.swift`.
2. Create `Views/<Name>Panel.swift`, reading shared state via
   `@Environment(AppState.self)`.
3. Put new side effects in a service (`Services/`), not the view. Services that
   touch external processes should be `actor`s.

### Change a runtime constant (port, queue name, label)

These live in exactly one place per side: `G2010Manager/Sources/G2010Manager/Models/RuntimeConstants.swift`
(Swift) and the `PRINTSERVER_*` env knobs (shell — see the top of
`harness/printserver-control.sh`). Printer identity additionally honors
`PRINTSERVER_DEVICE_URI` (pipeline), `G2010_DEVICE_URI` /
`G2010_SCANNER_DEVICE` (app), and the app auto-detects the scanner by parsing
`scanimage -L`.

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

- Machine identity is portable as of TASK-011 (dynamic HOME/USER, `@HOME@`
  plist token, `$HOME`-relative filter path, device overrides, scanner
  auto-detect) but still single-printer-family: full sibling-model support
  (per-model PPD regen) remains a recipe, not code.
- The IPP listener is LAN-reachable by construction (`ippeveprinter` 2.4.x
  has no bind flag; `restart`/`status` report and warn on scope) — firewall
  guidance lives in `docs/03-OPERATIONS.md`.
- Swift unit tests live in `G2010Manager/Tests/` — extend them with the
  changed behavior, not just new code paths.

## 8. Style & conventions

- **Shell:** `#!/bin/bash`, `set -euo pipefail`, quote expansions, overridable
  `PRINTSERVER_*` env knobs in the controller.
- **Swift process execution (TASK-006):** argv-form
  `ShellExecutor.run(_:arguments:)` for anything dynamic (job IDs, UIDs,
  paths, scan settings) — arguments bypass shell parsing, so they cannot
  inject. `run(bash:)` only where a shell operator is required (pipes in
  `MaintenanceService`, whose interpolation is constants-only) — any other
  `run(bash:)` use fails CI. Stdout-to-disk streaming uses `outputFile:`,
  never shell `>` with an interpolated path.
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
- Provenance: `packaging/generate-manifest.sh` (run by `create-dmg.sh` after
  codesigning) writes `runtime/manifest.json` — app/git/Gutenprint/Homebrew
  versions plus sha256 of every bundled binary and the XML database; the app
  shows it under Print Server → Build Manifest. Redistribution additionally
  needs Developer ID + notarization (fail-closed signing, not yet wired).

## 10. Checklist before opening a PR

1. `./tests/test-printserver-control.sh` passes.
2. `cd G2010Manager && swift build` passes (CI will also check release build).
3. `bash -n` on any shell script you touched; `plutil -lint` on any plist.
4. No vendored trees, spool, logs, or documents staged (`git status` clean of them).
5. Docs updated if behavior changed.
6. Filled in the PR template, including how you tested and whether real hardware
   was involved.
