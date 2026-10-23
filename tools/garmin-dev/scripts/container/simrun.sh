#!/usr/bin/env bash
# RUNS IN: container (baked as /usr/local/bin/simrun.sh). Run from the
# project root. DEVICE is required; the jungle/app name is derived from the
# current dir via resolve_jungle (JUNGLE=<file> overrides, --install uses
# <app>-dev.jungle). --install (MTP sideload to a watch) does not work in the
# container.
#
# Build + load a device into the simulator, or (with --install) sideload it to a
# connected watch -- optionally overriding app-settings defaults. Pass overrides as
# environment variables named exactly after the <property id> entries in
# resources/settings/properties.xml, e.g.:
#
#     theme=1 ./simrun.sh fr955                # in the sim
#     theme=2 units=1 ./simrun.sh fr955        # two overrides, in the sim
#     theme=1 ./simrun.sh --install fr955      # sideloaded to the watch
#
# Mechanism: Application.Properties is seeded from the .prg's properties.xml
# defaults, so for each override we patch that default into properties.xml for the
# build, then restore the file. In the sim we also restart it with the .SET cleared
# so the new defaults take. --install builds the dev variant (<app>-dev.jungle)
# and sideloads via install.sh -- the dev sideload reads its settings
# only from the .prg (not Connect-editable), so the baked defaults ARE the effective
# settings. (If a prior dev install persisted settings, `make uninstall` first.)
set -euo pipefail

INSTALL=0
if [ "${1:-}" = "--install" ]; then INSTALL=1; shift; fi

DEVICE="${1:?usage: simrun.sh [--install] DEVICE}"
ROOT="$(pwd)"
PROPS="$ROOT/resources/settings/properties.xml"
KEY="$HOME/.connectiq/developer_key.der"
SDKBIN="$("$HOME/go/bin/connect-iq-sdk-manager-cli" sdk current-path --bin)"

# Sim/monkeydo logs go to the host-mounted cache dir, keyed
# by container name, so they are readable from the host and survive the
# container. Falls back to /tmp when the mount is absent.
LOG_DIR="$HOME/.cache/garmin-dev"
{ [ -d "$LOG_DIR" ] && [ -w "$LOG_DIR" ]; } || LOG_DIR=/tmp
SIM_LOG="$LOG_DIR/$(hostname).sim.log"
DO_LOG="$LOG_DIR/$(hostname).monkeydo.log"

. /usr/local/bin/ciq-jungle.sh
resolve_jungle
APP_BASE="$APP"
if [ "$INSTALL" = 1 ]; then
    JUNGLE="$ROOT/${APP_BASE}-dev.jungle"; PRG="$ROOT/bin/${APP_BASE}-dev-${DEVICE}.prg"
    if [ ! -f "$JUNGLE" ]; then
        echo "error: --install needs ${APP_BASE}-dev.jungle in $ROOT" >&2
        exit 1
    fi
else
    JUNGLE="$ROOT/$JUNGLE";                PRG="$ROOT/bin/${APP_BASE}-${DEVICE}.prg"
fi
mkdir -p "$ROOT/bin"

# Collect overrides: env vars whose name matches a property id in properties.xml.
ov=()
while read -r id; do
    v="${!id-__UNSET__}"
    [ "$v" = "__UNSET__" ] || ov+=("$id=$v")
done < <(grep -oE 'id="[a-zA-Z]+"' "$PROPS" | sed -E 's/id="(.*)"/\1/')

restore() { [ -f "$PROPS.bak" ] && mv -f "$PROPS.bak" "$PROPS"; return 0; }  # return 0 so set -e doesn't abort when there's no .bak (no overrides)

if [ ${#ov[@]} -gt 0 ]; then
    echo ">> settings overrides: ${ov[*]}"
    cp "$PROPS" "$PROPS.bak"; trap restore EXIT
    for kv in "${ov[@]}"; do
        k="${kv%%=*}"; val="${kv#*=}"
        sed -i -E "s#(<property id=\"$k\" type=\"[a-z]+\">)[^<]*(</property>)#\1${val}\2#" "$PROPS"
    done
fi

echo ">> build $DEVICE"
"$SDKBIN/monkeyc" -d "$DEVICE" -f "$JUNGLE" -o "$PRG" -y "$KEY" -w >/dev/null
restore; trap - EXIT   # the .prg has baked the defaults; restore properties.xml now

if [ "$INSTALL" = 1 ]; then
    echo ">> sideload to watch"
    "$ROOT/scripts/install.sh" "$DEVICE" "$PRG"
    echo "installed $DEVICE (overrides: ${ov[*]:-none})"
    exit 0
fi

# monkeydo natively switches the running sim to the pushed device (verified
# SDK 9.1; no restart needed for that). A restart is needed when settings
# overrides must reseed the .SET store — and as a recovery when the sim
# wedges (see below).
if [ ${#ov[@]} -gt 0 ]; then
    echo ">> restart sim + clear persisted store (so the overridden defaults apply)"
    pkill -f 'bin/simulato[r]' 2>/dev/null || true; sleep 2
    find /tmp/com.garmin.connectiq -iname "${APP_BASE}*.SET" -delete 2>/dev/null || true
fi

start_sim_if_needed() {
    pgrep -f 'bin/simulato[r]' >/dev/null \
        || { setsid env GDK_BACKEND=x11 "$SDKBIN/simulator" >"$SIM_LOG" 2>&1 </dev/null & sleep 5; }
    for i in $(seq 1 60); do ss -ltn 2>/dev/null | grep -q ':1234' && break; sleep 0.3; done
    SIM_PID="$(pgrep -f 'bin/simulato[r]' | head -1)"
}
start_sim_if_needed

# One attached monkeydo at a time; stacked ones from
# previous runs accumulate (the loaded app keeps running without its
# monkeydo).
pkill -f "monkeydodeux.MonkeyDoDeux" 2>/dev/null || true

load_app() {
    > "$DO_LOG"
    setsid "$SDKBIN/monkeydo" "$PRG" "$DEVICE" >>"$DO_LOG" 2>&1 </dev/null &
}

# Verify the push actually applied, and recover by
# restarting the sim when it did not. Pushes are unreliable: into a freshly
# started sim they can die silently (port 1234 opens before the shell
# handler is ready), and an aged sim can wedge into a state where monkeydo
# exits 0 but the push is ignored. Verification: this container's sim
# window (matched by _NET_WM_PID, since the X server is shared) must carry
# the target device's displayName in its title. A same-device reload cannot
# be verified this way (the title does not change) and is pushed blind.
EXPECT="$(jq -r '.displayName // empty' "$HOME/.Garmin/ConnectIQ/Devices/$DEVICE/compiler.json" 2>/dev/null)"
loaded_ok() {
    local id pid
    for id in $(xprop -root _NET_CLIENT_LIST 2>/dev/null | grep -oE '0x[0-9a-f]+'); do
        pid="$(xprop -id "$id" _NET_WM_PID 2>/dev/null | awk '{print $NF}')"
        [ "$pid" = "$SIM_PID" ] || continue
        case "$(xprop -id "$id" _NET_WM_NAME 2>/dev/null)" in
            *"$EXPECT"*) return 0 ;;
        esac
    done
    return 1
}

if [ -n "$EXPECT" ] && loaded_ok; then
    load_app
    echo "loaded $DEVICE (same device already shown: reload not verifiable; overrides: ${ov[*]:-none}); logs $DO_LOG"
else
    load_app
    APPLIED=0
    if [ -n "$EXPECT" ]; then
        for i in $(seq 1 25); do
            sleep 1
            loaded_ok && { APPLIED=1; break; }
        done
        if [ "$APPLIED" != 1 ]; then
            echo ">> push not applied after 25s; restarting sim and retrying"
            pkill -f 'bin/simulato[r]' 2>/dev/null || true; sleep 2
            start_sim_if_needed
            load_app
            for i in $(seq 1 30); do
                sleep 1
                loaded_ok && { APPLIED=1; break; }
            done
        fi
        if [ "$APPLIED" = 1 ]; then
            echo "loaded $DEVICE (verified on screen; overrides: ${ov[*]:-none}); logs $DO_LOG"
        else
            echo "WARN: $DEVICE still not shown; check $SIM_LOG and $DO_LOG" >&2
            exit 1
        fi
    else
        echo "loaded $DEVICE (unverified: no displayName for device; overrides: ${ov[*]:-none}); logs $DO_LOG"
    fi
fi
