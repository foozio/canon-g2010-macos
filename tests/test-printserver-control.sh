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
  grep -Fq "$text" "$file" || fail "expected '$text' in $file"
}

assert_not_contains() {
  local file="$1" text="$2"
  if grep -Fq "$text" "$file"; then
    fail "did not expect '$text' in $file"
  fi
}

make_fixture() {
  local name="$1" mode="$2" dir
  dir="$TEST_TMP/$name"
  mkdir -p "$dir/bin" "$dir/home/Library/LaunchAgents"
  : > "$dir/events"
  : > "$dir/server.log"
  printf '<plist><dict/></plist>\n' > "$dir/source.plist"

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
if [ -e "$STATE_READY" ]; then
  echo 9999
elif [ "${TEST_MODE:-}" = success ] && [ ! -e "$STATE_KILLED" ]; then
  echo 4242
elif [ "${TEST_MODE:-}" = unsafe ]; then
  echo 5151
fi
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
  EVENTS="$dir/events" \
  STATE_READY="$dir/ready" \
  STATE_KILLED="$dir/killed" \
  HOME="$dir/home" \
  PATH="$dir/bin:/usr/bin:/bin" \
  KILL_BIN="$dir/bin/kill" \
  PRINTSERVER_PLIST_SOURCE="$dir/source.plist" \
  PRINTSERVER_LOG="$dir/server.log" \
  PRINTSERVER_WAIT_ATTEMPTS=2 \
  "$CONTROL" restart > "$dir/stdout" 2> "$dir/stderr"
}

test_restart_has_one_owner_and_waits_until_ready() {
  make_fixture success success
  local events="$TEST_TMP/success/events"
  assert_contains "$events" "launchctl bootout gui/"
  assert_contains "$events" "kill 4242"
  assert_contains "$events" "launchctl bootstrap gui/"
  assert_contains "$events" "launchctl kickstart -k gui/"
  assert_contains "$TEST_TMP/success/stdout" "ready on port 8632"

  local bootout kill bootstrap kickstart
  bootout=$(grep -n 'launchctl bootout' "$events" | cut -d: -f1)
  kill=$(grep -n 'kill 4242' "$events" | cut -d: -f1)
  bootstrap=$(grep -n 'launchctl bootstrap' "$events" | cut -d: -f1)
  kickstart=$(grep -n 'launchctl kickstart' "$events" | cut -d: -f1)
  [ "$bootout" -lt "$kill" ] || fail "bootout must precede orphan cleanup"
  [ "$kill" -lt "$bootstrap" ] || fail "cleanup must precede bootstrap"
  [ "$bootstrap" -lt "$kickstart" ] || fail "bootstrap must precede kickstart"
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

test_desktop_command_delegates_to_single_owner_controller() {
  local desktop_command="$ROOT/G2010-PrintServer.command"
  assert_contains "$desktop_command" "harness/printserver-control.sh"
  assert_contains "$desktop_command" "restart"
  assert_not_contains "$desktop_command" "nohup"
  assert_not_contains "$desktop_command" "pkill"
  assert_not_contains "$desktop_command" "start-printserver.sh"
}

test_restart_has_one_owner_and_waits_until_ready
test_refuses_to_kill_unrelated_listener
test_reports_startup_timeout
test_desktop_command_delegates_to_single_owner_controller
echo "PASS: print server lifecycle controller"
