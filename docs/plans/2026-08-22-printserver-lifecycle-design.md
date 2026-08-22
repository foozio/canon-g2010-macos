# Permanent Print Server Lifecycle Design

## Problem

The print queue targets a local `ippeveprinter` process on TCP port 8632. The
LaunchAgent is configured with `KeepAlive`, while `G2010-PrintServer.command`
also kills the current process and starts an independent background instance.
After the kill, launchd and the command can both start `ippeveprinter`; one
wins the port and the other exits with `EX_CONFIG`. Repeated failures leave the
LaunchAgent throttled or in on-demand-only mode, so eventually no server owns
the port and printing stops before the conversion pipeline runs.

## Design

Launchd becomes the sole owner of the server process. A new control script
performs an atomic restart: unload the registered job (which disables
`KeepAlive`), terminate only an orphaned `ippeveprinter` listening on port 8632,
reload the checked-in LaunchAgent definition, force-start it, and poll the port
until ready. The Desktop command delegates to that control script and never
starts a second server itself.

The LaunchAgent definition is checked into the repository and installed into
`~/Library/LaunchAgents` by the control script. Runtime paths remain explicit,
matching the existing single-user installation. Startup output and errors are
written to the existing IPP log so bind or configuration failures are visible.

## Failure handling

Every launchctl step tolerates the expected “not loaded” state but fails on an
actual bootstrap or kickstart error. Orphan cleanup is restricted to a process
that is both listening on port 8632 and named `ippeveprinter`; unrelated
processes are never killed. Readiness is bounded, reports the relevant log on
failure, and exits nonzero so the Desktop command shows a meaningful result.

## Verification

Shell tests run the controller against fake `launchctl`, `lsof`, and `kill`
commands. They prove unload-before-cleanup-before-bootstrap ordering, safe
orphan filtering, readiness success, and bounded startup failure. Live
verification resets the actual service, confirms one listener and an active
LaunchAgent, submits a small PDF through `G2010IPP`, and confirms all three
pipeline stages were reached.
