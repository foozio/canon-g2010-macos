#!/bin/bash
# Launcher for G2010 IPP print server - provides full env under launchd
#
# NOTE (TASK-002): ippeveprinter (CUPS 2.4.x) has NO listen-address option and
# always binds all interfaces (*:8632, no IPP auth). Do NOT attempt `-l 127.0.0.1`:
# -l sets the human-readable printer *location* string, not the bind address.
# Bind scope is reported by printserver-control.sh (status prints it, restart
# warns when it is not loopback-only); see docs/03-OPERATIONS.md "Verify the bind".
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
# Privacy (TASK-003): spool files hold user document bytes and stage logs echo
# job metadata — create everything owner-only (0600). Same-user processes are
# unaffected; the controller additionally tightens pre-existing files.
umask 077
# Portable identity (TASK-011): derive the invoking user instead of hardcoding
# one. launchd already sets HOME/USER for agents; the fallbacks cover direct
# invocation with a stripped environment.
: "${USER:=$(id -un)}"
: "${HOME:=$(eval echo "~$USER")}"
export USER HOME
export TMPDIR="${TMPDIR:-/tmp}"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

exec /opt/homebrew/opt/cups/bin/ippeveprinter \
  -p 8632 \
  -c "$SCRIPT_DIR/print-pipeline.sh" \
  -d "$SCRIPT_DIR/spool" \
  -M Canon \
  -m "G2010 series" \
  -f application/pdf \
  CanonG2010
