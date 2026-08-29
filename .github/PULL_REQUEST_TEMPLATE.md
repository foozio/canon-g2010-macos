## What does this change?

<!-- One or two sentences on what this PR does and why. Link the issue: "Fixes #123". -->

## Type

- [ ] Bug fix
- [ ] New feature
- [ ] Documentation
- [ ] Refactor / cleanup
- [ ] CI / packaging

## How was it tested?

<!--
Describe how you verified the change. At minimum, the standard checks must pass:
  ./tests/test-printserver-control.sh
  (cd G2010Manager && swift build)
If you changed the print/scan path, say whether you tested against real hardware
(a Canon G2010) and on what macOS version.
-->

## Checklist

- [ ] I read [CONTRIBUTING.md](../CONTRIBUTING.md) and followed the hard rules.
- [ ] I did not commit vendored trees (`gutenprint-src/`, `cnijfilter2-src/`), spool, logs, or user documents.
- [ ] I did not introduce `sudo`, root daemons, or kernel extensions.
- [ ] I did not hardcode a user's `$HOME` or a specific printer serial in shared code paths.
- [ ] I updated docs if behavior changed.
- [ ] The change is focused (one concern per PR).
