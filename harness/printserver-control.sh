#!/bin/bash
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
LABEL="${PRINTSERVER_LABEL:-com.foozio.g2010.printserver}"
PORT="${PRINTSERVER_PORT:-8632}"
PLIST_SOURCE="${PRINTSERVER_PLIST_SOURCE:-$ROOT/launchd/$LABEL.plist}"
PLIST_DEST="${PRINTSERVER_PLIST_DEST:-$HOME/Library/LaunchAgents/$LABEL.plist}"
SERVER_LOG="${PRINTSERVER_LOG:-$ROOT/harness/ippeve.log}"
WAIT_ATTEMPTS="${PRINTSERVER_WAIT_ATTEMPTS:-15}"

LAUNCHCTL_BIN="${LAUNCHCTL_BIN:-launchctl}"
LSOF_BIN="${LSOF_BIN:-lsof}"
PS_BIN="${PS_BIN:-ps}"
KILL_BIN="${KILL_BIN:-kill}"
SLEEP_BIN="${SLEEP_BIN:-sleep}"

DOMAIN="gui/$(id -u)"
SERVICE="$DOMAIN/$LABEL"

listener_pids() {
  "$LSOF_BIN" -nP -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true
}

stop_registered_service() {
  "$LAUNCHCTL_BIN" bootout "$SERVICE" >/dev/null 2>&1 || true
}

remove_orphaned_listener() {
  local pid command
  for pid in $(listener_pids); do
    command=$("$PS_BIN" -p "$pid" -o comm= 2>/dev/null || true)
    if [ "$(basename "$command")" != "ippeveprinter" ]; then
      echo "ERROR: port $PORT is owned by PID $pid ($command), not ippeveprinter; refusing to stop it." >&2
      return 1
    fi
    "$KILL_BIN" "$pid"
  done

  for _ in 1 2 3 4 5; do
    [ -z "$(listener_pids)" ] && return 0
    "$SLEEP_BIN" 1
  done

  echo "ERROR: orphaned ippeveprinter did not release port $PORT." >&2
  return 1
}

install_agent() {
  [ -f "$PLIST_SOURCE" ] || {
    echo "ERROR: LaunchAgent template not found: $PLIST_SOURCE" >&2
    return 1
  }
  mkdir -p "$(dirname "$PLIST_DEST")"
  cp "$PLIST_SOURCE" "$PLIST_DEST"
  plutil -lint "$PLIST_DEST" >/dev/null
}

wait_until_ready() {
  local attempt=1
  while [ "$attempt" -le "$WAIT_ATTEMPTS" ]; do
    if [ -n "$(listener_pids)" ]; then
      echo "G2010 print server is ready on port $PORT."
      return 0
    fi
    "$SLEEP_BIN" 1
    attempt=$((attempt + 1))
  done

  echo "ERROR: G2010 print server did not become ready on port $PORT." >&2
  if [ -f "$SERVER_LOG" ]; then
    tail -20 "$SERVER_LOG" >&2
  fi
  return 1
}

restart() {
  stop_registered_service
  remove_orphaned_listener || return 1
  install_agent || return 1
  "$LAUNCHCTL_BIN" bootstrap "$DOMAIN" "$PLIST_DEST" || return 1
  "$LAUNCHCTL_BIN" kickstart -k "$SERVICE" || return 1
  wait_until_ready
}

status() {
  if [ -n "$(listener_pids)" ]; then
    "$LAUNCHCTL_BIN" print "$SERVICE" 2>/dev/null | sed -n '1,18p'
    echo "G2010 print server is ready on port $PORT."
    return 0
  fi
  echo "G2010 print server is not listening on port $PORT." >&2
  return 1
}

case "${1:-restart}" in
  restart) restart ;;
  status) status ;;
  *)
    echo "Usage: $0 {restart|status}" >&2
    exit 2
    ;;
esac
