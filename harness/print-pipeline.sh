#!/bin/bash
# G2010 standalone print pipeline (no cupsd required)
# Called by ippeveprinter as: script job-id user title copies options [files...]
#
# pipefail so a cgpdftoraster/Gutenprint failure is not masked by a succeeding
# usb backend (the "completed but silent" class); -u for strictness. No -e:
# the explicit rc-capture/tail flow below must run even when a stage fails.
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PPD="$SCRIPT_DIR/stp-bjc-G2000-series.5.3.ppd"
if [ ! -f "$PPD" ]; then
  PPD="$SCRIPT_DIR/../G2010_gutenprint/stp-bjc-G2000-series.5.3.ppd"
fi
DEVURI="${PRINTSERVER_DEVICE_URI:-usb://Canon/G2010%20series?serial=0C7A8F}"
GP_FILTER="$HOME/gp/cupsexec/filter/rastertogutenprint.5.3"
# Installer rewrites this when bundled Gutenprint XML is present (DMG layout).
STP_DATA_PATH=""
[ -n "$STP_DATA_PATH" ] && export STP_DATA_PATH

jobid="${1:-}"; user="${2:-}"; title="${3:-}"; copies="${4:-1}"; opts="${5:-}"; shift 5 2>/dev/null || true
pdf="${1:-}"

[ -z "$pdf" ] || [ ! -f "$pdf" ] && { echo "ERROR: no input file" >&2; exit 1; }

echo "INFO: pipeline start job=$jobid file=$pdf" >&2

export PPD="$PPD"

# Per-job stage logs (TASK-014): concurrent jobs must not interleave.
# $jobid is ippeveprinter-assigned (numeric); sanitize defensively since it
# becomes a filename. The fixed /tmp/g2010_<stage>.log symlinks track the
# latest job so documented log paths keep working.
safejob="${jobid//[^A-Za-z0-9_-]/_}"
: "${safejob:=manual}"
CG_LOG="/tmp/g2010_cg.$safejob.log"
GP_LOG="/tmp/g2010_gp.$safejob.log"
USB_LOG="/tmp/g2010_usb.$safejob.log"

# 1) PDF -> CUPS raster (Apple filter)
# 2) raster -> Canon BJ stream (native arm64 Gutenprint)
# 3) stream -> USB device (Apple usb backend, direct invocation)
/usr/libexec/cups/filter/cgpdftoraster "$jobid" "$user" "$title" "$copies" "$opts" "$pdf" 2>"$CG_LOG" \
 | "$GP_FILTER" "$jobid" "$user" "$title" "$copies" "$opts" 2>"$GP_LOG" \
 | DEVICE_URI="$DEVURI" /usr/libexec/cups/backend/usb "$jobid" "$user" "$title" "$copies" "$opts" 2>"$USB_LOG"

rc=$?
echo "INFO: pipeline done rc=$rc" >&2
tail -3 "$GP_LOG" >&2
ln -sf "$CG_LOG" /tmp/g2010_cg.log
ln -sf "$GP_LOG" /tmp/g2010_gp.log
ln -sf "$USB_LOG" /tmp/g2010_usb.log
exit $rc
