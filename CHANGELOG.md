# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Open-source governance: `LICENSE` (GPL-3.0-or-later), `CONTRIBUTING.md`,
  `CODE_OF_CONDUCT.md`, `SECURITY.md`, `THIRD_PARTY_NOTICES.md`.
- GitHub issue/PR templates and CI workflow (build + shell test suite).
- `docs/07-DEVELOPMENT.md` — developer setup, build, test, and contribution guide.

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

[Unreleased]: https://github.com/foozio/canon-g2010-macos/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/foozio/canon-g2010-macos/releases/tag/v1.0.0
