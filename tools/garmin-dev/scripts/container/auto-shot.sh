#!/usr/bin/env bash
# RUNS IN: container (vendored; baked as /usr/local/bin/auto-shot.sh). Run from project root.
# Fully automated: build a device, (re)launch the simulator, WAIT until the watch
# face has actually rendered, then screenshot the sim window.
#
# "Is the device booted yet?" -- the simulator emits no render-complete event
# (nothing lands in monkeydo.log). But the window itself is the signal: before the
# app draws, the sim window is static and matches a blank baseline; once the face
# renders it differs a lot from that baseline, then settles to just the second
# hand (~0.2% of pixels/sec). So: capture a blank baseline (sim up, app not loaded
# yet), then poll until a frame differs a lot from the baseline AND is stable vs
# the previous frame. Frames are normalised to a fixed size before comparing, so
# it's device-agnostic and never trips ImageMagick's same-size requirement.
#
# Usage: ./auto-shot.sh [-t|--transparent] DEVICE [out.png]
#   (out default: /tmp/ciq-sim.png; -t = transparent background)
# Vendored change: generic. DEVICE is required; the jungle/app name is
# derived from the current dir via resolve_jungle (JUNGLE=<file> overrides).
set -euo pipefail
export LC_ALL=C.UTF-8   # vendored change (was C): keep IM fx decimal point AND xprop UTF8 title conversion working; force '.' decimal in ImageMagick fx output

SHOT_ARGS=()
if [ "${1:-}" = "-t" ] || [ "${1:-}" = "--transparent" ]; then SHOT_ARGS+=(--transparent); shift; fi
DEVICE="${1:?usage: auto-shot.sh [-t] DEVICE [out.png]}"
OUT="${2:-/tmp/ciq-sim.png}"
KEY="$HOME/.connectiq/developer_key.der"
SDKBIN="$("$HOME/go/bin/connect-iq-sdk-manager-cli" sdk current-path --bin)"
# Vendored change: sim/monkeydo logs to the host-mounted cache dir (see simrun.sh).
LOG_DIR="$HOME/.cache/garmin-dev"
{ [ -d "$LOG_DIR" ] && [ -w "$LOG_DIR" ]; } || LOG_DIR=/tmp
SIM_LOG="$LOG_DIR/$(hostname).sim.log"
DO_LOG="$LOG_DIR/$(hostname).monkeydo.log"
. /usr/local/bin/ciq-jungle.sh
resolve_jungle
PRG="bin/${APP}-${DEVICE}.prg"
PROPS="resources/settings/properties.xml"
TMP="$(mktemp -d)"
restore() { [ -f "$PROPS.bak" ] && mv -f "$PROPS.bak" "$PROPS"; return 0; }  # return 0 so set -e doesn't abort when there's no .bak (no overrides)
trap 'restore; rm -rf "$TMP"' EXIT

# Settings overrides: env vars named after properties.xml <property id>s are patched
# into the defaults for this build (same as simrun.sh), then restored. Clearing the
# sim's stored .SET on restart (below) is what lets the new defaults actually take.
ov=()
while read -r id; do
    v="${!id-__UNSET__}"
    [ "$v" = "__UNSET__" ] || ov+=("$id=$v")
done < <(grep -oE 'id="[a-zA-Z]+"' "$PROPS" | sed -E 's/id="(.*)"/\1/')
if [ ${#ov[@]} -gt 0 ]; then
    echo ">> settings overrides: ${ov[*]}"
    cp "$PROPS" "$PROPS.bak"
    for kv in "${ov[@]}"; do
        k="${kv%%=*}"; val="${kv#*=}"
        sed -i -E "s#(<property id=\"$k\" type=\"[a-z]+\">)[^<]*(</property>)#\1${val}\2#" "$PROPS"
    done
fi

echo ">> build $DEVICE"
"$SDKBIN/monkeyc" -d "$DEVICE" -f "$JUNGLE" -o "$PRG" -y "$KEY" -w >/dev/null
restore   # the .prg has baked the defaults; restore properties.xml now

echo ">> restart simulator (fresh blank baseline for render detection)"
pkill -f 'bin/simulato[r]' 2>/dev/null || true; sleep 2
if [ ${#ov[@]} -gt 0 ]; then
    find /tmp/com.garmin.connectiq -iname "${APP}*.SET" -delete 2>/dev/null || true
fi
setsid env GDK_BACKEND=x11 "$SDKBIN/simulator" >"$SIM_LOG" 2>&1 </dev/null &
for i in $(seq 1 80); do ss -ltn 2>/dev/null | grep -q ':1234' && break; sleep 0.3; done

# Blank baseline: the sim window with no app loaded yet (retry until it exists).
for i in $(seq 1 12); do "$(dirname "$0")/screenshot.sh" "$TMP/base.png" >/dev/null 2>&1 && break; sleep 0.5; done

echo ">> load app"
pkill -f "monkeydodeux.MonkeyDoDeux" 2>/dev/null || true   # vendored: one attached monkeydo at a time
load_app() {
    > "$DO_LOG"
    setsid "$SDKBIN/monkeydo" "$PRG" "$DEVICE" >>"$DO_LOG" 2>&1 </dev/null &
    DO_PID=$!
}
load_app
# Vendored change: the sim here is always freshly started, and a push into a
# cold sim can die silently (port opens before the shell handler is ready).
# A healthy monkeydo stays attached; an early exit means retry.
for attempt in 1 2; do
    sleep 4
    kill -0 "$DO_PID" 2>/dev/null && break
    echo ">> load did not take (cold sim); retrying"
    load_app
done

# Changed-pixel count between two frames, each normalised to 240x240 first so
# size never matters. Returns the full count (=100%) if compare fails.
# Vendored change: `magick compare -metric AE` output is build-dependent (the
# IM7 AppImage is Q16-HDRI: scientific notation, counts scaled by 65535), so
# compute the changed fraction via a difference composite instead.
N=57600 # 240*240
pct() {
  magick "$1" -resize 240x240\! "$TMP/a.png" 2>/dev/null
  magick "$2" -resize 240x240\! "$TMP/b.png" 2>/dev/null
  magick "$TMP/a.png" "$TMP/b.png" -compose difference -composite \
    -colorspace gray -threshold 8% -format "%[fx:round(mean*57600)]" info: 2>/dev/null \
    || echo "$N"
}

echo ">> wait for render (differs from blank, then settles)"
prev="$TMP/base.png"; ready=0
for t in $(seq 1 30); do
  sleep 1
  "$(dirname "$0")/screenshot.sh" "$TMP/cur.png" >/dev/null 2>&1 || continue
  db=$(pct "$TMP/cur.png" "$TMP/base.png")   # vs blank baseline -> "appeared"
  dp=$(pct "$TMP/cur.png" "$prev")           # vs previous frame  -> "settled"
  if awk -v db="${db:-$N}" -v dp="${dp:-$N}" -v n="$N" \
       'BEGIN{exit !(db/n*100>20 && dp/n*100<2)}'; then
    echo "   rendered + settled at ~${t}s"; ready=1; break
  fi
  cp "$TMP/cur.png" "$TMP/prev.png"; prev="$TMP/prev.png"
done
[ "$ready" = 1 ] || echo "   WARN: render not confirmed within 30s; capturing anyway"

"$(dirname "$0")/screenshot.sh" --crop ${SHOT_ARGS[@]+"${SHOT_ARGS[@]}"} "$OUT"
