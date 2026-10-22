#!/bin/bash
# RUNS IN: container (image ENTRYPOINT)
#
# Modes:
#   entrypoint.sh            interactive shell (one-shot `docker run`)
#   entrypoint.sh -c "..."   scripted one-shot
#   entrypoint.sh hold       persistent container (garmin-dev.sh up):
#                            bootstrap the display stack, then sleep forever;
#                            all work arrives via docker exec.

# Bash history lives on the host in the mounted ~/.cache/garmin-dev, keyed by
# container name (= the project slug, set as hostname by the launcher).
# Never write history (or any state) into the project tree: it is a mounted
# repo and project-local dotdirs get committed by accident.
HIST_DIR="$HOME/.cache/garmin-dev"
if [ -d "$HIST_DIR" ] && [ -w "$HIST_DIR" ]; then
    export HISTFILE="$HIST_DIR/$(hostname).bash_history"
fi

# Headless display fallback: DISPLAY empty (one-shot with no host X) or :99
# (persistent headless: the launcher sets it as container env so docker exec
# sessions inherit it) -> own X stack. openbox is required, not cosmetic:
# the screenshot window lookup reads _NET_CLIENT_LIST, which only a WM
# populates. x11vnc/noVNC make the sim interactive from a browser (the
# launcher publishes 5900/6080).
DISPLAY_MODE="host X"
if [ -z "${DISPLAY:-}" ] || [ "${DISPLAY:-}" = ":99" ]; then
    export DISPLAY=:99
    export GDK_BACKEND=x11
    export LIBGL_ALWAYS_SOFTWARE=1
    if [ ! -e /tmp/.X11-unix/X99 ]; then
        Xvfb :99 -screen 0 1280x1024x24 >/tmp/xvfb.log 2>&1 &
        for i in $(seq 1 50); do [ -e /tmp/.X11-unix/X99 ] && break; sleep 0.1; done
        openbox >/tmp/openbox.log 2>&1 &
        x11vnc -display :99 -forever -shared -nopw -quiet -bg -o /tmp/x11vnc.log
        websockify --daemon --web /usr/share/novnc 6080 localhost:5900 >/tmp/websockify.log 2>&1
    fi
    DISPLAY_MODE="headless Xvfb :99 (VNC 5900, noVNC http://localhost:6080/vnc.html)"
fi

# Put the active SDK's tools (monkeyc, monkeydo, simulator) on PATH when an
# SDK is set; otherwise point at setup.
CLI="$HOME/go/bin/connect-iq-sdk-manager-cli"
SDK_BIN="$("$CLI" sdk current-path --bin 2>/dev/null || true)"
if [ -n "$SDK_BIN" ] && [ -d "$SDK_BIN" ]; then
    export PATH="$SDK_BIN:$PATH"
    SDK_STATE="SDK: $(basename "$(dirname "$SDK_BIN")")"
else
    SDK_STATE="SDK: not set up — run 'garmin-setup' from the project dir"
fi

echo "Garmin Dev | java $(java -version 2>&1 | head -1 | grep -oP '\"\K[^\"]+') | $(go version | awk '{print $3}')"
echo "Project: $(pwd) | $SDK_STATE | display: $DISPLAY_MODE"
echo ""

if [ "${1:-}" = "hold" ]; then
    exec sleep infinity
fi

exec /bin/bash "$@"
