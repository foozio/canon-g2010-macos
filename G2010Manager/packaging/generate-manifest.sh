#!/bin/bash
# generate-manifest.sh — write build-provenance runtime/manifest.json (TASK-007).
#
# Usage: generate-manifest.sh <repo-root> <runtime-dir> <app-version>
# Records: app version, timestamp, builder, git state, Gutenprint tag+sha,
# Homebrew formula versions, the single-source runtime-producer decision,
# codesign mode/policy, and sha256 of every bundled binary/library/PPD/source
# plus a fingerprint of the Gutenprint XML database.
#
# Called by create-dmg.sh AFTER codesigning so shas cover the shipped bytes.
# Standalone-runnable for testing (point it at any runtime-shaped tree).
set -euo pipefail

REPO_ROOT="${1:?usage: generate-manifest.sh <repo-root> <runtime-dir> <app-version>}"
RUNTIME_DIR="${2:?usage: generate-manifest.sh <repo-root> <runtime-dir> <app-version>}"
APP_VERSION="${3:?usage: generate-manifest.sh <repo-root> <runtime-dir> <app-version>}"

fail() { echo "ERROR: $*" >&2; exit 1; }
[ -d "$RUNTIME_DIR" ] || fail "runtime dir not found: $RUNTIME_DIR"
command -v python3 >/dev/null || fail "python3 required for manifest generation"
command -v shasum >/dev/null || fail "shasum required for manifest generation"

BUILT_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BUILDER="$(whoami)@$(hostname -s 2>/dev/null || hostname)"

if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  GIT_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
  GIT_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  if [ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]; then GIT_DIRTY="true"; else GIT_DIRTY="false"; fi
else
  GIT_SHA="unknown"; GIT_BRANCH="unknown"; GIT_DIRTY="unknown"
fi

GUTENPRINT_TAG="gutenprint-5_3_3"
GUTENPRINT_SRC="${GUTENPRINT_SRC:-$REPO_ROOT/gutenprint-src}"
if [ -d "$GUTENPRINT_SRC/.git" ]; then
  GUTENPRINT_SHA="$(git -C "$GUTENPRINT_SRC" rev-parse HEAD 2>/dev/null || echo unknown)"
else
  GUTENPRINT_SHA="unknown"
fi

brew_version() {
  brew list --versions "$1" 2>/dev/null | awk '{print $NF}' || true
}

FILES_JSON="$(cd "$RUNTIME_DIR" && find bin lib ppd source -type f \( -name "*.dylib" -o -name "*.so" -o -name "ippeveprinter" -o -name "scanimage" -o -name "rastertogutenprint.*" -o -name "*.ppd" -o -name "*.sh" -o -name "*.plist" -o -name "*.conf" \) 2>/dev/null | sort | while IFS= read -r f; do
  printf '%s  %s\n' "$(shasum -a 256 "$f" | awk '{print $1}')" "$f"
done)"

XML_DIR="share/gutenprint/5.3/xml"
if [ -d "$RUNTIME_DIR/$XML_DIR" ]; then
  XML_FILES="$(find "$RUNTIME_DIR/$XML_DIR" -type f | wc -l | tr -d ' ')"
  XML_SHA="$(cd "$RUNTIME_DIR/$XML_DIR" && find . -type f -exec shasum -a 256 {} + | sort -k2 | shasum -a 256 | awk '{print $1}')"
else
  XML_FILES="0"; XML_SHA="missing"
fi

export MANIFEST_APP_VERSION="$APP_VERSION" MANIFEST_BUILT_AT="$BUILT_AT" \
  MANIFEST_BUILDER="$BUILDER" MANIFEST_GIT_SHA="$GIT_SHA" \
  MANIFEST_GIT_BRANCH="$GIT_BRANCH" MANIFEST_GIT_DIRTY="$GIT_DIRTY" \
  MANIFEST_GUTENPRINT_TAG="$GUTENPRINT_TAG" MANIFEST_GUTENPRINT_SHA="$GUTENPRINT_SHA" \
  MANIFEST_BREW_CUPS="$(brew_version cups)" MANIFEST_BREW_SANE="$(brew_version sane-backends)" \
  MANIFEST_BREW_LIBUSB="$(brew_version libusb)" MANIFEST_BREW_LIBPNG="$(brew_version libpng)" \
  MANIFEST_BREW_JPEG="$(brew_version jpeg-turbo)" MANIFEST_BREW_OPENSSL="$(brew_version openssl@3)" \
  MANIFEST_FILES="$FILES_JSON" MANIFEST_XML_FILES="$XML_FILES" MANIFEST_XML_SHA="$XML_SHA"

python3 - "$RUNTIME_DIR/manifest.json" <<'PYEOF'
import json, os, sys

def env(key, default="unknown"):
    value = os.environ.get(key)
    return default if value is None or value == "" else value

def env_flag(key):
    value = os.environ.get(key, "")
    if value == "true":
        return True
    if value == "false":
        return False
    return value or "unknown"

manifest = {
    "schema": 1,
    "app": {"name": "G2010 Manager", "version": env("MANIFEST_APP_VERSION")},
    "built_at": env("MANIFEST_BUILT_AT"),
    "builder": env("MANIFEST_BUILDER"),
    "git": {
        "sha": env("MANIFEST_GIT_SHA"),
        "branch": env("MANIFEST_GIT_BRANCH"),
        "dirty": env_flag("MANIFEST_GIT_DIRTY"),
    },
    "gutenprint": {"tag": env("MANIFEST_GUTENPRINT_TAG"), "sha": env("MANIFEST_GUTENPRINT_SHA")},
    "homebrew": {
        "cups": env("MANIFEST_BREW_CUPS"),
        "sane-backends": env("MANIFEST_BREW_SANE"),
        "libusb": env("MANIFEST_BREW_LIBUSB"),
        "libpng": env("MANIFEST_BREW_LIBPNG"),
        "jpeg-turbo": env("MANIFEST_BREW_JPEG"),
        "openssl@3": env("MANIFEST_BREW_OPENSSL"),
    },
    "runtime_producer": "single-source: harness/launchd/G2010_gutenprint via runtime/source/ (TASK-001)",
    "codesign": {
        "mode": "ad-hoc",
        "policy": "Developer ID + notarization required for redistribution; see docs/07-DEVELOPMENT.md section 9 and .nuzli/github_secrets.md section 5",
    },
    "files": [
        {"path": path, "sha256": digest}
        for digest, path in (
            line.split("  ", 1)
            for line in env("MANIFEST_FILES", "").splitlines()
            if "  " in line
        )
    ],
    "xml_db": {"files": int(env("MANIFEST_XML_FILES", "0")), "sha256": env("MANIFEST_XML_SHA")},
}
with open(sys.argv[1], "w") as handle:
    json.dump(manifest, handle, indent=2)
    handle.write("\n")
PYEOF

echo "manifest written: $RUNTIME_DIR/manifest.json"
