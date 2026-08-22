#!/bin/bash
# Double-click to reset the launchd-owned Canon G2010 print server.
CONTROL="/Users/foozio/Downloads/Codes/g2010i/harness/printserver-control.sh"

if "$CONTROL" restart; then
  echo "✅ G2010 print server RUNNING — you can print now."
else
  echo "❌ Failed to start — see ~/Downloads/Codes/g2010i/harness/ippeve.log"
fi
sleep 5
