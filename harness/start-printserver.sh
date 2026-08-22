#!/bin/bash
# Launcher for G2010 IPP print server - provides full env under launchd
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOME="/Users/foozio"
export USER="foozio"
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
