#!/bin/bash
# Double-click to reset the launchd-owned Canon G2010 print server.
# Resolved relative to this file so the checkout works from any location.
CONTROL="$(cd "$(dirname "$0")" && pwd)/harness/printserver-control.sh"

if "$CONTROL" restart; then
  echo "✅ G2010 print server RUNNING — you can print now."
else
  echo "❌ Failed to start — see ~/Library/Logs/G2010PrintServer.log"
fi
sleep 5
