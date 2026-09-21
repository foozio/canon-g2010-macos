#!/bin/bash
# test-print-pipeline.sh — TASK-009 fixture tests (no hardware needed).
#
# The pipeline hardcodes absolute stage paths (/usr/libexec/..., $GP_FILTER),
# so the fixture runs a COPY with only those paths rewritten to stubs (via
# sed); control flow, argv parsing, rc capture, and pipefail semantics are the
# pristine script's own. Stage logs are redirected into the temp dir so the
# test never touches /tmp/g2010_*.log.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PIPELINE="$ROOT/harness/print-pipeline.sh"
TEST_TMP=$(mktemp -d)
trap '[ "${TEST_KEEP_TMP:-0}" = 1 ] || rm -rf "$TEST_TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# make_copy <name> <exit1> <exit2> <exit3>
# Stage stubs pass stdin through and exit with the given code; the last stub
# records what it received to prove data flowed (or didn't). The backend stub
# also records the DEVICE_URI it was given (TASK-011 override plumbing).
make_copy() {
  local name="$1" e1="$2" e2="$3" e3="$4" dir
  dir="$TEST_TMP/$name"
  mkdir -p "$dir"
  printf 'dummy-pdf-bytes' > "$dir/job.pdf"

  cat > "$dir/stage1" <<EOF
#!/bin/bash
cat
exit $e1
EOF
  cat > "$dir/stage2" <<EOF
#!/bin/bash
cat
exit $e2
EOF
  cat > "$dir/stage3" <<EOF
#!/bin/bash
cat > "$dir/received.bin"
printf '%s' "\$DEVICE_URI" > "$dir/devuri.txt"
exit $e3
EOF
  chmod +x "$dir/stage1" "$dir/stage2" "$dir/stage3"

  sed -e "s|/usr/libexec/cups/filter/cgpdftoraster|$dir/stage1|" \
      -e "s|\"\$GP_FILTER\"|$dir/stage2|" \
      -e "s|/usr/libexec/cups/backend/usb|$dir/stage3|" \
      -e "s|/tmp/g2010_|$dir/job_|g" \
      "$PIPELINE" > "$dir/run.sh"
  chmod +x "$dir/run.sh"
  echo "$dir"
}

run_copy() {
  local dir="$1"
  shift
  printf 'dummy-pdf-bytes' | "$dir/run.sh" "$@" > "$dir/stdout" 2> "$dir/stderr"
  echo $?
}

test_success_path_stays_zero() {
  local dir rc
  dir=$(make_copy success 0 0 0)
  rc=$(run_copy "$dir" 1 printer "Doc" 1 "" "$dir/job.pdf")
  [ "$rc" -eq 0 ] || fail "success path exited $rc, want 0"
  [ -s "$dir/received.bin" ] || fail "success path delivered no bytes downstream"
  [ "$(cat "$dir/devuri.txt")" = "usb://Canon/G2010%20series?serial=0C7A8F" ] || fail "default device URI not propagated to backend"
}

test_device_uri_override_is_honored() {
  local dir rc
  dir=$(make_copy devuri 0 0 0)
  rc=$(PRINTSERVER_DEVICE_URI="usb://Test/Printer?serial=ZZ" run_copy "$dir" 1 printer "Doc" 1 "" "$dir/job.pdf")
  [ "$rc" -eq 0 ] || fail "override path exited $rc, want 0"
  [ "$(cat "$dir/devuri.txt")" = "usb://Test/Printer?serial=ZZ" ] || fail "PRINTSERVER_DEVICE_URI override not propagated (got $(cat "$dir/devuri.txt"))"
}

test_middle_stage_failure_is_not_masked() {
  local dir rc
  dir=$(make_copy midfail 0 3 0)
  rc=$(run_copy "$dir" 1 printer "Doc" 1 "" "$dir/job.pdf")
  [ "$rc" -ne 0 ] || fail "middle-stage exit 3 masked by succeeding last stage (pipefail missing?)"
}

test_first_stage_failure_is_not_masked() {
  local dir rc
  dir=$(make_copy firstfail 2 0 0)
  rc=$(run_copy "$dir" 1 printer "Doc" 1 "" "$dir/job.pdf")
  [ "$rc" -ne 0 ] || fail "first-stage exit 2 masked by succeeding last stage (pipefail missing?)"
}

test_missing_input_still_fails_cleanly() {
  local dir
  dir=$(make_copy noinput 0 0 0)
  if printf '' | "$dir/run.sh" > "$dir/stdout" 2> "$dir/stderr"; then
    fail "zero-arg invocation unexpectedly succeeded"
  fi
  grep -Fq "ERROR: no input file" "$dir/stderr" || fail "zero-arg path lost the friendly error (set -u fallthrough?)"
}

test_concurrent_jobs_keep_separate_stage_logs() {
  local a b
  a=$(make_copy jobA 0 0 0)
  b=$(make_copy jobB 0 0 0)
  printf 'data-A' | "$a/run.sh" 111 printer "A" 1 "" "$a/job.pdf" > "$a/stdout" 2> "$a/stderr" &
  printf 'data-B' | "$b/run.sh" 222 printer "B" 1 "" "$b/job.pdf" > "$b/stdout" 2> "$b/stderr" &
  wait
  [ -f "$a/job_cg.111.log" ] || fail "job A cg log missing"
  [ -f "$b/job_cg.222.log" ] || fail "job B cg log missing"
  [ ! -e "$a/job_cg.222.log" ] || fail "job B log leaked into job A dir"
  [ -L "$a/job_cg.log" ] || fail "latest symlink missing"
}

test_jobid_is_sanitized_for_log_filenames() {
  local dir rc
  dir=$(make_copy sanitize 0 0 0)
  rc=$(run_copy "$dir" "7/8" printer "Doc" 1 "" "$dir/job.pdf")
  [ "$rc" -eq 0 ] || fail "sanitized path exited $rc, want 0"
  [ -f "$dir/job_cg.7_8.log" ] || fail "sanitized log name missing"
  [ ! -e "$dir/7" ] || fail "jobid traversed out of the log dir"
}

test_success_path_stays_zero
test_device_uri_override_is_honored
test_middle_stage_failure_is_not_masked
test_first_stage_failure_is_not_masked
test_missing_input_still_fails_cleanly
test_concurrent_jobs_keep_separate_stage_logs
test_jobid_is_sanitized_for_log_filenames
echo "PASS: print pipeline failure propagation"
