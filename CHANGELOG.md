# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] — 2026-10-04

### Added
- **Design Pattern Architecture Reconstruction (`eleev/swift-design-patterns`)**:
  - **MVVM-C**: Decoupled presentation logic into `@Observable` ViewModels (`DashboardViewModel`, `PrintServerViewModel`, `ScanViewModel`, `JobsViewModel`, `MaintenanceViewModel`, `TroubleshootViewModel`, `MenuBarViewModel`) and centralized navigation flow/modals in `AppCoordinator`.
  - **Dependency Injection & Container**: Added `DependencyContainer` implementing abstract factory and service container patterns, enabling full mockability and constructor injection.
  - **Command Pattern**: Encapsulated hardware actions and quick-fixes into executable commands (`StandardCleaningCommand`, `DeepCleaningCommand`, `NozzleCheckCommand`, `PrintAlignmentCommand`, `ClearStuckJobsCommand`, `ReinstallQueueCommand`, `RestartServerCommand`, `RemoveStaleQueuesCommand`, `CancelJobCommand`, `CancelJobsCommand`).
  - **State Machine Pattern**: Formalized state modeling for maintenance availability (`MaintenanceAvailability`) and queue state (`QueueState`), eliminating scattered boolean flags.
  - **Structural Adapters & Facade**: Created `ShellExecuting` (`DefaultShellExecutor`), `CUPSServiceProtocol` (`DefaultCUPSService`), and `MaintenanceServiceProtocol` (`DefaultMaintenanceService`); refactored `AppState` into a high-level application Facade.
  - **Design for Testability**: Added dedicated test suites for Dependency Container, Commands, ViewModels, and Coordinator, expanding coverage to 58 automated tests.
- **Application Versioning**:
  - Centralized version constants in `RuntimeConstants` (`appVersion`, `buildVersion`, `displayVersion`, `fullVersionString`).
  - Added CLI version support (`G2010Manager --version`, `-v`).
  - Surfaced version badges in the Menu Bar extra and Dashboard footer.
  - Dynamically resolved version metadata in DMG packaging (`create-dmg.sh`).
- Open-source governance: `LICENSE` (GPL-3.0-or-later), `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `THIRD_PARTY_NOTICES.md`.
- GitHub issue/PR templates and CI workflow (build + shell test suite).
- `docs/07-DEVELOPMENT.md` — developer setup, build, test, and contribution guide.

### Fixed
- Single-source runtime provisioning (TASK-001): `RuntimeManager` now installs
  copies of the tested `harness/` + `launchd/` + PPD sources with
  install-prefix substitution instead of generating divergent scripts. The old
  generated `print-pipeline.sh` misread the `ippeveprinter` job arguments
  (`$1` is the job ID, the file comes last), which broke printing for
  app-installed runtimes. Launcher/pipeline now live at the runtime root
  (Gen-1 flat layout); stale `scripts/` copies are removed on install.
  `create-dmg.sh` bundles the pristine sources under `runtime/source/`, and
  `tests/test-runtime-convergence.sh` (run in CI) locks the contract.
- Pipeline failure propagation (TASK-009): `harness/print-pipeline.sh` now
  runs under `set -uo pipefail` (deliberately no `-e`, preserving the
  rc-capture/tail flow) with `set -u`-safe arg defaults, so a cgpdftoraster
  or Gutenprint failure can no longer be masked by a succeeding usb backend
  into a "completed but silent" job. Covered by `tests/test-print-pipeline.sh`
  (mid/first-stage failure, success, zero-arg cases; run in CI).
- Honest GUI error reporting (TASK-010): user-initiated mutations go through
  `AppState.perform()`, which refreshes and routes failures to a shared
  `ErrorBanner` (Dashboard, Print Server, Jobs, menu bar); the Troubleshoot
  panel reports per-action green/red instead of unconditional success, and
  its "Reset USB" button is renamed since it only clears jobs. Background
  refresh reads keep `try?` by design.
- Portability (TASK-011): no hardcoded author home directory remains in
  tracked files (CI-locked). Shell identity is dynamic (`id -un`, `@HOME@` plist
  token substituted at install, `$HOME`-relative filter path, `PRINTSERVER_`
  device-URI override, relocatable `.command`); Swift centralizes constants
  in `RuntimeConstants`, discovers the scanner via `scanimage -L`, and honors
  device overrides. Dev builds now require `G2010_REPO_ROOT` (see
  `docs/07-DEVELOPMENT.md`). The checked-in PPD carries an `@GP_FILTER@`
  token rewritten at install — run installs (controller/app), not the raw
  checkout, as the supported flow.
- UX consistency (TASK-016): scan destination unified to `~/Pictures`
  (Apple Image Capture convention) via `ScanSettings.defaultDestination`;
  status colors are `SwiftUI.Color` end-to-end (no string plumbing); the Jobs
  table drops its duplicate "Document" column — `lpstat` exposes no titles,
  so the job ID is shown once under an honest header.
- Dead code + stale config removal (TASK-013): unreferenced `PrinterState` /
  `PrinterCondition` deleted (verified zero references); abandoned port-8631
  private-cupsd configs, the RE-harness `capture` backend, and the Canon
  experiment PPD removed from disk (all gitignored, unreferenced — protocol
  findings already live in `docs/05-PROTOCOL-NOTES.md`).
- Swift unit tests (TASK-012): app logic split into a `G2010ManagerCore`
  library (same directory, exclude-partitioned — no file moves) with a
  `G2010ManagerTests` target (23 tests: settings naming, lpstat parsing,
  pixma extraction, shell execution incl. timeout/redirect, constants
  coherence, provisioning contract), run in CI. Cross-module API is now
  explicitly `public`.
- Log isolation + rotation (TASK-014): pipeline stage logs are per-job
  (`/tmp/g2010_<stage>.<jobid>.log`, jobid sanitized) with `latest` symlinks
  preserving documented paths; the server log rotates at 5 MB on `restart`
  (one `.1` backup, daemon-stopped so no stale fd); the in-app console
  follows rotation via a refresh-loop hook (Swift-tested).
- Robust job parsing + drain-safe queue reinstall (TASK-015): `lpstat` rows
  parse across real macOS columnar output and multiple date formats (dates
  previously never parsed — verified against live completed-jobs output),
  malformed rows are salvaged instead of dropped, and `ensureQueue()` leaves
  a healthy queue alone (`force:` still recreates, e.g. capability refresh).

### Security
- IPP exposure clarified and surfaced (TASK-002): `ippeveprinter` (CUPS 2.4.x)
  has no listen-address option — live-verified it binds all interfaces
  (`*:8632` IPv4+IPv6, no authentication), so the loopback-only claim in the
  docs was wrong and is now corrected. `printserver-control.sh status` prints
  the bind scope and `restart` warns on stderr when it is not loopback-only
  (fixture-tested); `docs/03-OPERATIONS.md` gains a "Verify the bind" section
  with firewall guidance. Deliberately warn-only: refusing to run would brick
  printing since no loopback-only mode exists without elevated firewall rules.
- Spool/log privacy hardening (TASK-003): runtime + spool dirs are `0700`,
  spool files and the server log `0600` (new files born owner-only via
  `umask 077` in the launcher; `restart` re-tightens pre-existing files and
  sweeps spool files older than 3 days, `PRINTSERVER_SPOOL_MAX_AGE_DAYS`
  overrides). Dev-machine spool/log residue deleted; `docs/03-OPERATIONS.md`
  documents retention and the FileVault assumption.
- GUI lifecycle unified behind the tested controller (TASK-004): the Manager
  app's restart/stop now shell out to `printserver-control.sh` (argv-form,
  no shell-string) instead of reimplementing launchctl/pkill logic — the
  unguarded GUI `pkill -f ippeveprinter` is gone, and GUI restarts inherit
  the single-owner ordering, orphan guard, and bind-scope warning. The
  controller gains a `stop` verb (bootout + guarded kill); the app bundles
  it under `runtime/source/` and `RuntimeManager` mirrors pristine sources
  there for the controller to consume. Verified end-to-end against real
  launchd + `ippeveprinter` on an isolated port/label.
- Maintenance safety (TASK-005): backend exit codes are enforced (failures
  raise Error alerts instead of false "Success"), Deep Cleaning requires a
  confirmation dialog stating the ink cost, and all four actions disable with
  a reason unless the server is running, the queue is enabled, and no jobs
  are active. Mechanical effect on firmware `VER:1.040` remains unverified —
  documented in `docs/03-OPERATIONS.md`; USB-absent is reported attempt-time
  via the backend exit code (no slow device probe in the poll loop).
- Shell-string discipline (TASK-006): all Swift process execution except the
  `MaintenanceService` pipe uses argv-form `run(_:arguments:)` with absolute
  system binary paths (no shell parsing of job IDs, UIDs, paths, or scan
  settings); scan output streams via a new `outputFile:` redirect instead of
  shell `>`, and scan failures now throw on nonzero exit. A CI lint step
  fails any new `run(bash:)` use outside `MaintenanceService.swift`.
- DMG provenance (TASK-007): `packaging/generate-manifest.sh` records
  `runtime/manifest.json` at package time (app/git/Gutenprint/Homebrew
  versions, sha256 of bundled binaries, XML database fingerprint, ad-hoc
  codesign statement), shown in the app under Print Server → Build Manifest.
  Signing stays ad-hoc; Developer ID + notarization remain future work.
- CI least-privilege (TASK-008): `ci.yml` runs read-only; the release job
  grants only `contents:write` (release attach) + `actions:write` (artifact
  upload). Dependabot watches `github-actions` weekly. Push protection and
  the next release-attach verification are manual maintainer steps.

## [1.0.0] — 2026-08-29

### Added
- G2010 Manager v1.0.0 — native macOS SwiftUI app (menu bar + dashboard) for
  print-server control, scanning, job management, maintenance, and log viewing.
- Self-contained packaging: `create-dmg.sh` builds a DMG bundling ippeveprinter,
  the Gutenprint filter + XML database, scanimage/SANE, and all dylibs
  (relocated via `install_name_tool`).

## [0.x] — 2026-08-22 (pre-app shell phase)

### Added
- Working userspace print path: launchd-owned `ippeveprinter` on port 8632,
  three-stage streaming pipeline (cgpdftoraster → Gutenprint → Apple usb backend).
- `harness/printserver-control.sh` lifecycle controller with single-owner
  kill-guard, plus fixture-based test suite.
- Gutenprint 5.3.3 built natively for arm64; generated PPD for `bjc-G2000-series`.
- SANE-based scanning (`pixma` backend).
- Documentation set `docs/01–06` (diagnosis, architecture, operations,
  troubleshooting, protocol notes, build notes).

[Unreleased]: https://github.com/foozio/canon-g2010-macos/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/foozio/canon-g2010-macos/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/foozio/canon-g2010-macos/releases/tag/v1.0.0
