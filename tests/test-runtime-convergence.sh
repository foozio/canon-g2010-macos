#!/bin/bash
# test-runtime-convergence.sh — drift detector (no hardware needed).
#
# Locks the single-producer invariant: the Swift RuntimeManager must install
# copies of the TESTED checked-in sources (harness/, launchd/,
# G2010_gutenprint/) with install-prefix substitution only — never regenerate
# them from string templates. If any assertion below fails, the harness
# sources and RuntimeManager's substitution literals have diverged: update
# both sides together (see docs/07-DEVELOPMENT.md).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
RUNTIME="$ROOT/G2010Manager/Sources/G2010Manager/Services/RuntimeManager.swift"
PACKAGING="$ROOT/G2010Manager/packaging/create-dmg.sh"
LAUNCHER="$ROOT/harness/start-printserver.sh"
PIPELINE="$ROOT/harness/print-pipeline.sh"
PLIST="$ROOT/launchd/com.foozio.g2010.printserver.plist"

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

# 1. The harness launcher still exposes the exact literals RuntimeManager
#    substitutes (install-prefix contract), and derives user identity
#    dynamically (TASK-011 — no hardcoded user). If these change, update
#    installLauncherFromSource() to match.
assert_contains "$LAUNCHER" ': "${USER:=$(id -un)}"'
assert_contains "$LAUNCHER" ': "${HOME:=$(eval echo "~$USER")}"'
assert_contains "$LAUNCHER" '/opt/homebrew/opt/cups/bin/ippeveprinter'
assert_contains "$LAUNCHER" '-c "$SCRIPT_DIR/print-pipeline.sh"'
assert_contains "$LAUNCHER" '-d "$SCRIPT_DIR/spool"'
assert_contains "$LAUNCHER" '-f application/pdf'

# 1b. TASK-003: new spool/log files are born owner-only via the launcher.
assert_contains "$LAUNCHER" 'umask 077'

# 2. The harness pipeline still implements the real ippeveprinter argv
#    convention (job-id first, file last). The old divergent Swift template
#    treated $1 as the input file — that must never come back.
assert_contains "$PIPELINE" 'shift 5'
assert_contains "$PIPELINE" 'GP_FILTER="$HOME/gp/cupsexec/filter/rastertogutenprint.5.3"'
assert_contains "$PIPELINE" 'PRINTSERVER_DEVICE_URI:-'
assert_contains "$PIPELINE" 'PPD="$SCRIPT_DIR/stp-bjc-G2000-series.5.3.ppd"'
assert_not_contains "$PIPELINE" 'INPUT_FILE="$1"'

# 2b. TASK-009: pipefail (+ -u) must stay — a mid-pipe stage failure must fail
#    the job, not read as success at the CUPS layer.
assert_contains "$PIPELINE" 'set -uo pipefail'

# 3. The launchd template carries the @HOME@ token (not a hardcoded user);
#    both installers substitute it (controller via sed, app via prefix
#    substitution).
assert_contains "$PLIST" '@HOME@/Library/Application Support/G2010PrintServer/start-printserver.sh'
assert_contains "$PLIST" '@HOME@/Library/Logs/G2010PrintServer.log'
assert_not_contains "$PLIST" '/Users/foozio'

# 4. RuntimeManager copies sources; it must not contain script generators.
assert_contains "$RUNTIME" 'installLauncherFromSource'
assert_contains "$RUNTIME" 'installPipelineFromSource'
assert_contains "$RUNTIME" 'installLaunchAgentPlist'
assert_contains "$RUNTIME" 'readRuntimeSource'
assert_not_contains "$RUNTIME" 'generatePrintPipelineScript'
assert_not_contains "$RUNTIME" 'generateStartPrintServerScript'
assert_not_contains "$RUNTIME" 'INPUT_FILE="$1"'
# Installed launcher/pipeline live at the runtime root (flat Gen-1 layout).
assert_contains "$RUNTIME" 'appSupportDir.appendingPathComponent("print-pipeline.sh")'
assert_contains "$RUNTIME" 'appSupportDir.appendingPathComponent("start-printserver.sh")'
# 4b. TASK-011: single constants enum + retargeted substitution templates.
[ -f "$ROOT/G2010Manager/Sources/G2010Manager/Models/RuntimeConstants.swift" ] || fail "RuntimeConstants.swift missing"
assert_contains "$RUNTIME" 'RuntimeConstants'
assert_contains "$RUNTIME" 'template: "@HOME@"'
assert_contains "$RUNTIME" 'GP_FILTER=\"$HOME/gp/cupsexec/filter/rastertogutenprint.5.3\"'
assert_not_contains "$RUNTIME" '/Users/foozio'

# 5. The packager bundles the pristine sources for DMG installs.
assert_contains "$PACKAGING" 'mkdir -p "$RUNTIME_DIR/source"'
assert_contains "$PACKAGING" 'harness/printserver-control.sh" "$RUNTIME_DIR/source/"'
assert_contains "$PACKAGING" 'harness/start-printserver.sh" "$RUNTIME_DIR/source/"'
assert_contains "$PACKAGING" 'harness/print-pipeline.sh" "$RUNTIME_DIR/source/"'
assert_contains "$PACKAGING" 'launchd/com.foozio.g2010.printserver.plist" "$RUNTIME_DIR/source/"'
assert_contains "$PACKAGING" 'G2010_gutenprint/stp-bjc-G2000-series.5.3.ppd" "$RUNTIME_DIR/source/"'

# 6. TASK-002: ippeveprinter 2.4.x has no listen-address flag — `-l` sets the
#    printer *location* display string, not the bind address. The launcher must
#    never pretend to pin loopback with it (check code lines only — the
#    warning comment above the invocation mentions the flag deliberately);
#    the controller reports bind scope instead.
if grep -v '^[[:space:]]*#' "$LAUNCHER" | grep -Fq -- "-l 127"; then
  fail "launcher must not use -l as a listen-address flag (it sets location, not bind)"
fi
if grep -v '^[[:space:]]*#' "$LAUNCHER" | grep -Fq -- "-l localhost"; then
  fail "launcher must not use -l as a listen-address flag (it sets location, not bind)"
fi
assert_contains "$ROOT/harness/printserver-control.sh" "warn_unless_loopback"

# 7. TASK-004: the GUI drives the tested controller — no duplicate kill logic.
#    PrintServerService must shell out to printserver-control.sh (argv-form),
#    never pkill, and the packager must bundle the controller.
if grep -rn "pkill" "$ROOT/G2010Manager/Sources/G2010Manager/Services/" | grep -q .; then
  fail "Services/ must not contain pkill (use printserver-control.sh via PrintServerService)"
fi
assert_contains "$ROOT/G2010Manager/Sources/G2010Manager/Services/PrintServerService.swift" "printserver-control"
assert_contains "$ROOT/G2010Manager/Sources/G2010Manager/Services/PrintServerService.swift" 'arguments: [command]'
assert_contains "$PACKAGING" 'harness/printserver-control.sh" "$RUNTIME_DIR/source/"'

# 8. TASK-011 acceptance 1: no hardcoded author home in tracked files
#    (git grep covers tracked files only, so the gitignored .nuzli layer and
#    build residue can never trip this; the guard file itself is excluded
#    since it must name the pattern to check for it).
if git -C "$ROOT" grep -n "Users/foozio" -- . ':!tests/test-runtime-convergence.sh' | grep -q .; then
  git -C "$ROOT" grep -n "Users/foozio" -- . ':!tests/test-runtime-convergence.sh' >&2
  fail "tracked files must not hardcode /Users/foozio (see TASK-011)"
fi

echo "PASS: runtime convergence (single tested source of truth)"
