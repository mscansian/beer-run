# RUNS IN: container (baked as /etc/profile.d/garmin-dev.sh)
#
# Login shells started via `docker exec ... bash -l` bypass the entrypoint;
# this recreates its environment: active SDK on PATH, headless DISPLAY
# detection, per-project bash history.

_gd_sdk_bin="$("$HOME/go/bin/connect-iq-sdk-manager-cli" sdk current-path --bin 2>/dev/null || true)"
if [ -n "$_gd_sdk_bin" ] && [ -d "$_gd_sdk_bin" ]; then
    case ":$PATH:" in
        *":$_gd_sdk_bin:"*) ;;
        *) PATH="$_gd_sdk_bin:$PATH" ;;
    esac
    export PATH
fi
unset _gd_sdk_bin

# Headless container: point at the entrypoint's Xvfb unless the caller
# explicitly asked for no display (garmin-dev.sh shell --no-display).
if [ "${GARMIN_DEV_NO_DISPLAY:-}" != 1 ] && [ -z "${DISPLAY:-}" ] && [ -e /tmp/.X11-unix/X99 ]; then
    export DISPLAY=:99 GDK_BACKEND=x11 LIBGL_ALWAYS_SOFTWARE=1
fi

# History on the host (mounted ~/.cache/garmin-dev), keyed by container name;
# never write state into the mounted project tree (accidental-commit risk).
if [ -d "$HOME/.cache/garmin-dev" ] && [ -w "$HOME/.cache/garmin-dev" ]; then
    export HISTFILE="$HOME/.cache/garmin-dev/$(hostname).bash_history"
fi
