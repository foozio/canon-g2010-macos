#!/bin/bash
# Launcher for G2010 IPP print server - provides full env under launchd
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOME="/Users/foozio"
export USER="foozio"
export TMPDIR="${TMPDIR:-/tmp}"

exec /opt/homebrew/opt/cups/bin/ippeveprinter \
  -p 8632 \
  -c "/Users/foozio/Downloads/Codes/g2010i/harness/print-pipeline.sh" \
  -d "/Users/foozio/Downloads/Codes/g2010i/harness/spool_ipp" \
  -M Canon \
  -m "G2010 series" \
  -f application/pdf \
  CanonG2010
