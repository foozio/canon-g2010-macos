# Contributing to canon-g2010-macos

Thanks for your interest! This project makes a USB-only Canon PIXMA G2010 fully
work on Apple Silicon macOS (Tahoe) without Canon's defective macOS driver. It is
an integration of Apple's stock CUPS tools, a natively built Gutenprint driver, an
IPP userspace server, SANE scanning, and a SwiftUI manager app.

Please read this guide before opening a pull request. Also see
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) and the docs in [`docs/`](docs/).

---

## Quick orientation

| If you want to... | Read |
|---|---|
| Understand the problem this solves | [`docs/01-DIAGNOSIS.md`](docs/01-DIAGNOSIS.md) |
| Understand the architecture & data flow | [`docs/02-ARCHITECTURE.md`](docs/02-ARCHITECTURE.md), [`docs/07-DEVELOPMENT.md`](docs/07-DEVELOPMENT.md) |
| Run / operate the print server | [`docs/03-OPERATIONS.md`](docs/03-OPERATIONS.md) |
| Debug a failure | [`docs/04-TROUBLESHOOTING.md`](docs/04-TROUBLESHOOTING.md) |
| Understand the Canon USB protocol | [`docs/05-PROTOCOL-NOTES.md`](docs/05-PROTOCOL-NOTES.md) |
| Rebuild the Gutenprint driver from source | [`docs/06-BUILD-NOTES.md`](docs/06-BUILD-NOTES.md) |
| Set up a dev environment & build/test | [`docs/07-DEVELOPMENT.md`](docs/07-DEVELOPMENT.md) |

## Repository layout (first-party code)

```
G2010Manager/          # SwiftUI app (menu-bar + dashboard manager)
  Sources/             # Swift sources
  packaging/           # create-dmg.sh, create-icon.sh, Info.plist
harness/               # shell runtime: controller, launcher, print pipeline
launchd/               # LaunchAgent plist template
G2010_gutenprint/      # generated PPD (cupsFilter points at the native filter)
tests/                 # shell-based lifecycle tests
docs/                  # the documentation set
gutenprint-src/        # IGNORED — upstream Gutenprint source (fetch per docs/06)
cnijfilter2-src/       # IGNORED — Canon GPL Linux driver (protocol reference)
```

The two ignored trees are vendored upstream sources. Do **not** commit them; they
are fetched separately (see `docs/06-BUILD-NOTES.md`) and listed in `.gitignore`.

## Ways to contribute

1. **Bug reports & repro details** — the most valuable contribution. Use the bug
   issue template and include macOS version, printer firmware, and logs.
2. **Documentation fixes** — especially anything that is wrong or unclear in
   `docs/01–06`.
3. **Code fixes** — shell (`harness/`, `tests/`) or Swift (`G2010Manager/`).
4. **Protocol knowledge** — anything you learn about the IVEC/BJRaster3 protocol
   (see `docs/05`) is worth capturing.

## Development setup

Full step-by-step instructions, build commands, and how to run the test suite are
in [`docs/07-DEVELOPMENT.md`](docs/07-DEVELOPMENT.md). Minimum requirements:

- Apple Silicon Mac, macOS 14+ (developed on macOS 26).
- Xcode Command Line Tools (`xcode-select --install`).
- Homebrew with `autoconf automake libtool pkg-config` and, for runtime testing,
  `cups sane-backends libusb` (see `docs/07`).
- The Canon G2010 is only needed to test the actual print/scan path — most code,
  tests, and docs work without hardware attached.

## Making changes

### Workflow

1. Fork the repo and create a topic branch from `main`
   (e.g. `fix/pipeline-error-propagation`).
2. Make your change. Keep it focused — one concern per PR.
3. Run the checks below and make sure they pass.
4. Open a PR against `main`, filling in the PR template. Link any related issue.

### Before submitting, run the checks

```bash
# Shell lifecycle tests (no hardware needed)
./tests/test-printserver-control.sh

# Swift build (checks the manager app compiles)
cd G2010Manager && swift build

# Lint plists and scripts you touched
plutil -lint launchd/*.plist
bash -n harness/*.sh G2010-PrintServer.command
```

CI runs the shell test suite and the Swift build automatically (see
`.github/workflows/ci.yml`).

### Code style

- **Shell:** `#!/bin/bash`, `set -euo pipefail`, quote all expansions,
  `SCREAMING_SNAKE` for overridable env knobs (the controller is fully
  overridable via `PRINTSERVER_*` env vars — preserve that).
- **Swift:** follow standard Swift API design guidelines; keep services as
  `actor`s / enums where they already are; avoid adding external dependencies —
  the app intentionally uses only system frameworks.
- **PPD/config:** don't hand-edit generated artifacts; change the generator and
  regenerate.

### Hard rules (will block a PR)

- Do not commit anything from the ignored vendored trees or the spool.
- Do not commit user documents, logs containing document names, or credentials.
- Do not reintroduce `sudo`, root daemons, or kernel extensions — the whole point
  is a user-space solution.
- Do not hardcode a specific user's `$HOME` or printer serial into shared code
  paths; use runtime discovery or an overridable constant.

## Reporting security issues

Do **not** open a public issue for vulnerabilities. Use the process in
[`SECURITY.md`](SECURITY.md) (GitHub private vulnerability reporting).

## License of your contributions

This project is licensed under **GPL-3.0-or-later** (see [`LICENSE`](LICENSE)).
By submitting a contribution, you agree that your contribution will be licensed
under the same license. Note the project bundles several GPL upstream components;
`THIRD_PARTY_NOTICES.md` documents those.

## Questions?

Open a GitHub Discussion or issue. For anything security-sensitive, use the
private channel in `SECURITY.md`.
