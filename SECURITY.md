# Security Policy

## Supported versions

This is a single-user, local, hardware-integration tool. Only the latest release
on `main` is supported. There is no long-term-support branch.

## Reporting a vulnerability

**Do not open a public GitHub issue for a security vulnerability.**

Please report vulnerabilities privately so they can be fixed before disclosure:

- **Preferred:** use [GitHub private vulnerability reporting](https://github.com/foozio/canon-g2010-macos/security/advisories/new)
  (Security → Advisories → New draft security advisory).
- **Alternative:** email the maintainer at `foozio@users.noreply.github.com`.

You should receive an acknowledgement within a few days. We will work on a fix and
coordinate disclosure with you. Please give us a reasonable window (at least 30 days)
before public disclosure.

## Scope — what is in scope here

This project's own code and configuration:

- The Swift `G2010Manager` app and its `ShellExecutor`/service layer.
- The shell runtime in `harness/`, the LaunchAgent plist, and the print pipeline.
- The packaging scripts in `G2010Manager/packaging/`.

Relevant threat classes we care about:

- Command injection through the Manager's shell-out paths.
- Local information disclosure (e.g. spool files, logs, document titles).
- Network exposure of the IPP server beyond localhost.
- Supply-chain/tampering of the self-installed runtime and bundled dylibs.

## Out of scope

- Vulnerabilities in upstream components themselves (Gutenprint, SANE, CUPS,
  Canon's `cnijfilter2`). Please report those to their respective upstream
  projects; we will pick up fixes by updating the bundled versions.
- Issues that require an attacker who already has code execution as the same user
  (the whole tool runs as the invoking user by design).
- Social engineering or physical-access attacks on the printer hardware.

## Security notes for users

- Everything runs as your normal user — there is no root daemon and no kernel
  extension by design.
- The IPP listener should be reachable only from localhost. See
  `docs/03-OPERATIONS.md` and the troubleshooting docs.
- The print spool contains your documents; it lives under
  `~/Library/Application Support/G2010PrintServer/spool` and is excluded from
  version control.
