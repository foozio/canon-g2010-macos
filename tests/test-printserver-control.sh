#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CONTROL="$ROOT/harness/printserver-control.sh"
TEST_TMP=$(mktemp -d)
trap '[ "${TEST_KEEP_TMP:-0}" = 1 ] || rm -rf "$TEST_TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1" text="$2"
  grep -Fq -- "$text" "$file" || fail "expected '$text' in $file"
}

assert_not_contains() {
  local file="$1" text="$2"
  if grep -Fq -- "$text" "$file"; then
    fail "did not expect '$text' in $file"
  fi
}

make_fixture() {
  local name="$1" mode="$2" bind="${3:-loopback}" cmd="${4:-restart}" plist_content="${5:-<plist><dict/></plist>}" ppd_content="${6:-*PPD-Adobe: \"4.3\"}" dir
  dir="$TEST_TMP/$name"
  mkdir -p "$dir/bin" "$dir/home/Library/LaunchAgents"
  : > "$dir/events"
  [ -e "$dir/server.log" ] || : > "$dir/server.log"
  printf '#!/bin/bash\n' > "$dir/start-source.sh"
  printf '#!/bin/bash\n' > "$dir/pipeline-source.sh"
  printf '%s\n' "$plist_content" > "$dir/source.plist"
  printf '%s\n' "$ppd_content" > "$dir/source.ppd"

  cat > "$dir/bin/launchctl" <<'EOF'
#!/bin/bash
echo "launchctl $*" >> "$EVENTS"
if [ "$1" = kickstart ] && [ "${TEST_MODE:-}" = success ]; then
  : > "$STATE_READY"
fi
exit 0
EOF

  cat > "$dir/bin/lsof" <<'EOF'
#!/bin/bash
echo "lsof $*" >> "$EVENTS"
port="${PRINTSERVER_PORT:-8632}"
case "$*" in
  *-ti*)
    if [ -e "$STATE_READY" ]; then
      echo 9999
    elif [ "${TEST_MODE:-}" = success ] && [ ! -e "$STATE_KILLED" ]; then
      echo 4242
    elif [ "${TEST_MODE:-}" = unsafe ]; then
      echo 5151
    fi
    ;;
  *)
    if [ -e "$STATE_READY" ] || { [ "${TEST_MODE:-}" = success ] && [ ! -e "$STATE_KILLED" ]; }; then
      if [ "${TEST_BIND:-loopback}" = exposed ]; then
        echo "ippeveprinter 4242 user 4u IPv4 0t0 TCP *:$port (LISTEN)"
      else
        echo "ippeveprinter 4242 user 4u IPv4 0t0 TCP 127.0.0.1:$port (LISTEN)"
      fi
    fi
    ;;
esac
EOF

  cat > "$dir/bin/ps" <<'EOF'
#!/bin/bash
echo "ps $*" >> "$EVENTS"
if [ "${TEST_MODE:-}" = unsafe ]; then
  echo /usr/bin/python3
else
  echo /opt/homebrew/opt/cups/bin/ippeveprinter
fi
EOF

  cat > "$dir/bin/kill" <<'EOF'
#!/bin/bash
echo "kill $*" >> "$EVENTS"
: > "$STATE_KILLED"
EOF

  cat > "$dir/bin/sleep" <<'EOF'
#!/bin/bash
echo "sleep $*" >> "$EVENTS"
EOF

  chmod +x "$dir/bin/launchctl" "$dir/bin/lsof" "$dir/bin/ps" "$dir/bin/kill" "$dir/bin/sleep"

  TEST_MODE="$mode" \
  TEST_BIND="$bind" \
  EVENTS="$dir/events" \
  STATE_READY="$dir/ready" \
  STATE_KILLED="$dir/killed" \
  HOME="$dir/home" \
  PATH="$dir/bin:/usr/bin:/bin" \
  KILL_BIN="$dir/bin/kill" \
  PRINTSERVER_PLIST_SOURCE="$dir/source.plist" \
  PRINTSERVER_LOG="$dir/server.log" \
  PRINTSERVER_RUNTIME_DIR="$dir/runtime" \
  PRINTSERVER_START_SOURCE="$dir/start-source.sh" \
  PRINTSERVER_PIPELINE_SOURCE="$dir/pipeline-source.sh" \
  PRINTSERVER_PPD_SOURCE="$dir/source.ppd" \
  PRINTSERVER_WAIT_ATTEMPTS=2 \
  "$CONTROL" "$cmd" > "$dir/stdout" 2> "$dir/stderr"
}

test_restart_has_one_owner_and_waits_until_ready() {
  make_fixture success success
  local events="$TEST_TMP/success/events"
  assert_contains "$events" "launchctl bootout gui/"
  assert_contains "$events" "kill 4242"
  assert_contains "$events" "launchctl bootstrap gui/"
  assert_contains "$events" "launchctl kickstart -k gui/"
  assert_contains "$TEST_TMP/success/stdout" "ready on port 8632"
  [ -x "$TEST_TMP/success/runtime/start-printserver.sh" ] || fail "runtime launcher was not installed"
  [ -x "$TEST_TMP/success/runtime/print-pipeline.sh" ] || fail "runtime pipeline was not installed"
  [ -f "$TEST_TMP/success/runtime/stp-bjc-G2000-series.5.3.ppd" ] || fail "runtime PPD was not installed"

  local bootout kill bootstrap kickstart
  bootout=$(grep -n 'launchctl bootout' "$events" | cut -d: -f1)
  kill=$(grep -n 'kill 4242' "$events" | cut -d: -f1)
  bootstrap=$(grep -n 'launchctl bootstrap' "$events" | cut -d: -f1)
  kickstart=$(grep -n 'launchctl kickstart' "$events" | cut -d: -f1)
  [ "$bootout" -lt "$kill" ] || fail "bootout must precede orphan cleanup"
  [ "$kill" -lt "$bootstrap" ] || fail "cleanup must precede bootstrap"
  [ "$bootstrap" -lt "$kickstart" ] || fail "bootstrap must precede kickstart"
  assert_not_contains "$TEST_TMP/success/stderr" "WARNING"
}

test_refuses_to_kill_unrelated_listener() {
  if make_fixture unsafe unsafe; then
    fail "restart unexpectedly succeeded with an unrelated port owner"
  fi
  assert_not_contains "$TEST_TMP/unsafe/events" "kill 5151"
  assert_not_contains "$TEST_TMP/unsafe/events" "launchctl bootstrap"
  assert_contains "$TEST_TMP/unsafe/stderr" "not ippeveprinter"
}

test_reports_startup_timeout() {
  if make_fixture timeout timeout; then
    fail "restart unexpectedly succeeded without a listener"
  fi
  assert_contains "$TEST_TMP/timeout/stderr" "did not become ready"
  assert_contains "$TEST_TMP/timeout/events" "launchctl kickstart -k gui/"
}

test_warns_when_listener_exposed_beyond_localhost() {
  make_fixture exposed success exposed
  assert_contains "$TEST_TMP/exposed/stdout" "ready on port 8632"
  assert_contains "$TEST_TMP/exposed/stderr" "WARNING"
  assert_contains "$TEST_TMP/exposed/stderr" "not just localhost"
  assert_contains "$TEST_TMP/exposed/stderr" "no IPP authentication"
}

test_status_reports_bind_scope() {
  make_fixture loopback success loopback
  TEST_MODE=success \
  TEST_BIND=loopback \
  EVENTS="$TEST_TMP/loopback/events" \
  STATE_READY="$TEST_TMP/loopback/ready" \
  STATE_KILLED="$TEST_TMP/loopback/killed" \
  HOME="$TEST_TMP/loopback/home" \
  PATH="$TEST_TMP/loopback/bin:/usr/bin:/bin" \
  KILL_BIN="$TEST_TMP/loopback/bin/kill" \
  PRINTSERVER_PLIST_SOURCE="$TEST_TMP/loopback/source.plist" \
  PRINTSERVER_LOG="$TEST_TMP/loopback/server.log" \
  PRINTSERVER_RUNTIME_DIR="$TEST_TMP/loopback/runtime" \
  PRINTSERVER_START_SOURCE="$TEST_TMP/loopback/start-source.sh" \
  PRINTSERVER_PIPELINE_SOURCE="$TEST_TMP/loopback/pipeline-source.sh" \
  PRINTSERVER_PPD_SOURCE="$TEST_TMP/loopback/source.ppd" \
  PRINTSERVER_WAIT_ATTEMPTS=2 \
  "$CONTROL" status > "$TEST_TMP/loopback/status-out" 2> "$TEST_TMP/loopback/status-err"
  assert_contains "$TEST_TMP/loopback/status-out" "Listening on:"
  assert_contains "$TEST_TMP/loopback/status-out" "127.0.0.1:8632"
  assert_not_contains "$TEST_TMP/loopback/status-err" "WARNING"
}

test_sweeps_stale_spool_files_but_keeps_fresh_ones() {
  make_fixture sweep success
  touch -t 200001010000 "$TEST_TMP/sweep/runtime/spool/old.prn"
  printf 'fresh' > "$TEST_TMP/sweep/runtime/spool/new.prn"
  # Reset the fake listener lifecycle so the second restart replays it.
  rm -f "$TEST_TMP/sweep/ready" "$TEST_TMP/sweep/killed"
  make_fixture sweep success
  [ ! -e "$TEST_TMP/sweep/runtime/spool/old.prn" ] || fail "stale spool file survived restart"
  [ -f "$TEST_TMP/sweep/runtime/spool/new.prn" ] || fail "fresh spool file was swept"
}

test_locks_down_runtime_and_spool_permissions() {
  make_fixture perms success
  printf 'doc' > "$TEST_TMP/perms/runtime/spool/job.prn"
  # Reset the fake listener lifecycle so the second restart replays it.
  rm -f "$TEST_TMP/perms/ready" "$TEST_TMP/perms/killed"
  make_fixture perms success
  [ "$(stat -f %A "$TEST_TMP/perms/runtime")" = "700" ] || fail "runtime dir is not 0700"
  [ "$(stat -f %A "$TEST_TMP/perms/runtime/spool")" = "700" ] || fail "spool dir is not 0700"
  [ "$(stat -f %A "$TEST_TMP/perms/runtime/spool/job.prn")" = "600" ] || fail "spool file is not 0600"
  [ "$(stat -f %A "$TEST_TMP/perms/server.log")" = "600" ] || fail "server log is not 0600"
}

test_stop_unloads_service_and_kills_verified_listener() {
  make_fixture stopcase success loopback stop
  assert_contains "$TEST_TMP/stopcase/events" "launchctl bootout gui/"
  assert_contains "$TEST_TMP/stopcase/events" "kill 4242"
  assert_contains "$TEST_TMP/stopcase/stdout" "G2010 print server stopped."
  assert_not_contains "$TEST_TMP/stopcase/events" "launchctl bootstrap"
}

test_stop_refuses_foreign_listener() {
  if make_fixture stopunsafe unsafe loopback stop; then
    fail "stop unexpectedly succeeded with an unrelated port owner"
  fi
  assert_not_contains "$TEST_TMP/stopunsafe/events" "kill 5151"
  assert_contains "$TEST_TMP/stopunsafe/events" "launchctl bootout gui/"
  assert_contains "$TEST_TMP/stopunsafe/stderr" "not ippeveprinter"
}

test_install_agent_expands_home_token() {
  make_fixture tokenhome success loopback restart '<plist><dict><key>X</key><string>@HOME@/sub/dir</string></dict></plist>'
  assert_not_contains "$TEST_TMP/tokenhome/home/Library/LaunchAgents/com.foozio.g2010.printserver.plist" "@HOME@"
  assert_contains "$TEST_TMP/tokenhome/home/Library/LaunchAgents/com.foozio.g2010.printserver.plist" "$TEST_TMP/tokenhome/home/sub/dir"
}

test_install_rewrites_ppds_filter_path() {
  make_fixture ppdfilter success loopback restart '<plist><dict/></plist>' '*cupsFilter: "application/vnd.cups-raster 100 /WRONG/place/rastertogutenprint.5.3"'
  assert_not_contains "$TEST_TMP/ppdfilter/runtime/stp-bjc-G2000-series.5.3.ppd" "/WRONG/place"
  assert_contains "$TEST_TMP/ppdfilter/runtime/stp-bjc-G2000-series.5.3.ppd" "$TEST_TMP/ppdfilter/home/gp/cupsexec/filter/rastertogutenprint.5.3"
}

test_rotates_oversized_server_log() {
  make_fixture logrot success
  dd if=/dev/zero of="$TEST_TMP/logrot/server.log" bs=1m count=6 2>/dev/null
  rm -f "$TEST_TMP/logrot/ready" "$TEST_TMP/logrot/killed"
  make_fixture logrot success
  [ -f "$TEST_TMP/logrot/server.log.1" ] || fail "oversized server log was not rotated"
  [ "$(stat -f%z "$TEST_TMP/logrot/server.log.1")" -gt 5242880 ] || fail "rotated backup is not the oversized log"
  [ ! -e "$TEST_TMP/logrot/server.log" ] || fail "fresh server log should start absent after rotation"
}

test_desktop_command_delegates_to_single_owner_controller() {
  local desktop_command="$ROOT/G2010-PrintServer.command"
  assert_contains "$desktop_command" "harness/printserver-control.sh"
  assert_contains "$desktop_command" "restart"
  assert_not_contains "$desktop_command" "nohup"
  assert_not_contains "$desktop_command" "pkill"
  assert_not_contains "$desktop_command" "start-printserver.sh"
}

test_launchagent_runtime_is_outside_downloads() {
  local plist="$ROOT/launchd/com.foozio.g2010.printserver.plist"
  assert_not_contains "$plist" "/Downloads/"
  assert_contains "$plist" "/Library/Application Support/G2010PrintServer/"
  assert_contains "$plist" "/Library/Logs/G2010PrintServer.log"
}

test_restart_has_one_owner_and_waits_until_ready
test_refuses_to_kill_unrelated_listener
test_reports_startup_timeout
test_warns_when_listener_exposed_beyond_localhost
test_status_reports_bind_scope
test_sweeps_stale_spool_files_but_keeps_fresh_ones
test_locks_down_runtime_and_spool_permissions
test_stop_unloads_service_and_kills_verified_listener
test_stop_refuses_foreign_listener
test_install_agent_expands_home_token
test_install_rewrites_ppds_filter_path
test_rotates_oversized_server_log
test_desktop_command_delegates_to_single_owner_controller
test_launchagent_runtime_is_outside_downloads
echo "PASS: print server lifecycle controller"
