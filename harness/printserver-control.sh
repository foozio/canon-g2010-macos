#!/bin/bash
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
LABEL="${PRINTSERVER_LABEL:-com.foozio.g2010.printserver}"
PORT="${PRINTSERVER_PORT:-8632}"
PLIST_SOURCE="${PRINTSERVER_PLIST_SOURCE:-$ROOT/launchd/$LABEL.plist}"
PLIST_DEST="${PRINTSERVER_PLIST_DEST:-$HOME/Library/LaunchAgents/$LABEL.plist}"
SERVER_LOG="${PRINTSERVER_LOG:-$HOME/Library/Logs/G2010PrintServer.log}"
WAIT_ATTEMPTS="${PRINTSERVER_WAIT_ATTEMPTS:-15}"
RUNTIME_DIR="${PRINTSERVER_RUNTIME_DIR:-$HOME/Library/Application Support/G2010PrintServer}"
START_SOURCE="${PRINTSERVER_START_SOURCE:-$ROOT/harness/start-printserver.sh}"
PIPELINE_SOURCE="${PRINTSERVER_PIPELINE_SOURCE:-$ROOT/harness/print-pipeline.sh}"
PPD_SOURCE="${PRINTSERVER_PPD_SOURCE:-$ROOT/G2010_gutenprint/stp-bjc-G2000-series.5.3.ppd}"

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

listener_endpoints() {
  "$LSOF_BIN" -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | awk '/\(LISTEN\)$/ {print $(NF-1)}' || true
}

warn_unless_loopback() {
  local endpoints endpoint
  endpoints=$(listener_endpoints)
  [ -z "$endpoints" ] && return 0
  for endpoint in $endpoints; do
    case "$endpoint" in
      127.0.0.1:*|localhost:*|\[::1\]:*)
        ;;
      *)
        echo "WARNING: G2010 print server on port $PORT is listening on $endpoint, not just localhost." >&2
        echo "WARNING: any host that can reach this machine can submit print jobs (no IPP authentication)." >&2
        echo "WARNING: see docs/03-OPERATIONS.md \"Verify the bind\" for the check and firewall guidance." >&2
        return 0
        ;;
    esac
  done
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
  # The app passes its already-substituted installed plist as the source, so
  # source and destination may be identical — copy only when they differ.
  if [ "$PLIST_SOURCE" != "$PLIST_DEST" ]; then
    # Portable identity (TASK-011): the template's @HOME@ token becomes the
    # installing user's home (launchd expands nothing itself).
    sed "s|@HOME@|${HOME:-$(eval echo "~$(id -un)")}|g" "$PLIST_SOURCE" > "$PLIST_DEST"
  elif grep -Fq "@HOME@" "$PLIST_DEST"; then
    echo "ERROR: LaunchAgent plist still contains the unsubstituted @HOME@ token: $PLIST_DEST" >&2
    return 1
  fi
  plutil -lint "$PLIST_DEST" >/dev/null
}

install_runtime() {
  local source
  for source in "$START_SOURCE" "$PIPELINE_SOURCE" "$PPD_SOURCE"; do
    [ -f "$source" ] || {
      echo "ERROR: runtime source not found: $source" >&2
      return 1
    }
  done

  mkdir -p "$RUNTIME_DIR/spool" "$(dirname "$SERVER_LOG")"
  cp "$START_SOURCE" "$RUNTIME_DIR/start-printserver.sh"
  cp "$PIPELINE_SOURCE" "$RUNTIME_DIR/print-pipeline.sh"
  cp "$PPD_SOURCE" "$RUNTIME_DIR/stp-bjc-G2000-series.5.3.ppd"
  chmod 755 "$RUNTIME_DIR/start-printserver.sh" "$RUNTIME_DIR/print-pipeline.sh"
  # Portable filter path (TASK-011): the generated PPD bakes in its builder's
  # absolute filter location — repoint at this machine's ~/gp build (docs/06).
  sed -i '' 's|^\*cupsFilter:.*|*cupsFilter: "application/vnd.cups-raster 100 '"$HOME"'/gp/cupsexec/filter/rastertogutenprint.5.3"|' \
    "$RUNTIME_DIR/stp-bjc-G2000-series.5.3.ppd"

  # Privacy (TASK-003): the spool holds user document bytes and the server
  # log echoes job metadata — lock the tree down (owner-only). New spool/log
  # files are born 0600 via `umask 077` in the launcher; tighten pre-existing
  # files here so upgraded installs converge too.
  chmod 0700 "$RUNTIME_DIR" "$RUNTIME_DIR/spool"
  local spooled
  for spooled in "$RUNTIME_DIR"/spool/*; do
    [ -e "$spooled" ] || continue
    [ -f "$spooled" ] && chmod 0600 "$spooled"
  done
  touch "$SERVER_LOG"
  chmod 0600 "$SERVER_LOG"
  # Log hygiene (TASK-014): bound the server log with one backup generation.
  # Runs while the daemon is stopped (restart unloads first), so no open fd
  # survives the move — the relaunched daemon opens a fresh log.
  if [ "$(stat -f%z "$SERVER_LOG")" -gt "${PRINTSERVER_LOG_MAX_BYTES:-5242880}" ]; then
    mv -f "$SERVER_LOG" "$SERVER_LOG.1"
  fi
}

sweep_stale_spool() {
  local max_age="${PRINTSERVER_SPOOL_MAX_AGE_DAYS:-3}" spool="$RUNTIME_DIR/spool"
  [ -d "$spool" ] || return 0
  find "$spool" -maxdepth 1 -type f -mtime +"$max_age" -delete
}

wait_until_ready() {
  local attempt=1
  while [ "$attempt" -le "$WAIT_ATTEMPTS" ]; do
    if [ -n "$(listener_pids)" ]; then
      echo "G2010 print server is ready on port $PORT."
      warn_unless_loopback
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
  install_runtime || return 1
  sweep_stale_spool
  install_agent || return 1
  "$LAUNCHCTL_BIN" bootstrap "$DOMAIN" "$PLIST_DEST" || return 1
  "$LAUNCHCTL_BIN" kickstart -k "$SERVICE" || return 1
  wait_until_ready
}

status() {
  if [ -n "$(listener_pids)" ]; then
    "$LAUNCHCTL_BIN" print "$SERVICE" 2>/dev/null | sed -n '1,18p'
    echo "Listening on: $(listener_endpoints | tr '\n' ' ')"
    echo "G2010 print server is ready on port $PORT."
    warn_unless_loopback
    return 0
  fi
  echo "G2010 print server is not listening on port $PORT." >&2
  return 1
}

stop() {
  stop_registered_service
  remove_orphaned_listener || return 1
  echo "G2010 print server stopped."
}

case "${1:-restart}" in
  restart) restart ;;
  status) status ;;
  stop) stop ;;
  *)
    echo "Usage: $0 {restart|status|stop}" >&2
    exit 2
    ;;
esac
