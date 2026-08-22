#!/bin/bash
# G2010 standalone print pipeline (no cupsd required)
# Called by ippeveprinter as: script job-id user title copies options [files...]

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PPD="$SCRIPT_DIR/stp-bjc-G2000-series.5.3.ppd"
if [ ! -f "$PPD" ]; then
  PPD="$SCRIPT_DIR/../G2010_gutenprint/stp-bjc-G2000-series.5.3.ppd"
fi
DEVURI="usb://Canon/G2010%20series?serial=0C7A8F"
GP_FILTER="/Users/foozio/gp/cupsexec/filter/rastertogutenprint.5.3"

jobid="$1"; user="$2"; title="$3"; copies="${4:-1}"; opts="${5:-}"; shift 5 2>/dev/null
pdf="$1"

[ -z "$pdf" ] || [ ! -f "$pdf" ] && { echo "ERROR: no input file" >&2; exit 1; }

echo "INFO: pipeline start job=$jobid file=$pdf" >&2

export PPD="$PPD"

# 1) PDF -> CUPS raster (Apple filter)
# 2) raster -> Canon BJ stream (native arm64 Gutenprint)
# 3) stream -> USB device (Apple usb backend, direct invocation)
/usr/libexec/cups/filter/cgpdftoraster "$jobid" "$user" "$title" "$copies" "$opts" "$pdf" 2>/tmp/g2010_cg.log \
 | "$GP_FILTER" "$jobid" "$user" "$title" "$copies" "$opts" 2>/tmp/g2010_gp.log \
 | DEVICE_URI="$DEVURI" /usr/libexec/cups/backend/usb "$jobid" "$user" "$title" "$copies" "$opts" 2>/tmp/g2010_usb.log

rc=$?
echo "INFO: pipeline done rc=$rc" >&2
tail -3 /tmp/g2010_gp.log >&2
exit $rc
