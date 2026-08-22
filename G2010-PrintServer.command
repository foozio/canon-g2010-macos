#!/bin/bash
# Double-click to (re)start the Canon G2010 print server
pkill -f ippeveprinter 2>/dev/null; sleep 1
nohup /Users/foozio/Downloads/Codes/g2010i/harness/start-printserver.sh > /Users/foozio/Downloads/Codes/g2010i/harness/ippeve.log 2>&1 &
sleep 3
if lsof -iTCP:8632 -sTCP:LISTEN | grep -q LISTEN; then
  echo "✅ G2010 print server RUNNING — you can print now."
else
  echo "❌ Failed to start — see ~/Downloads/Codes/g2010i/harness/ippeve.log"
fi
sleep 5
