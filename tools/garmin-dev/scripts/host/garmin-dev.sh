#!/bin/bash
# RUNS ON: host
#
# Launch and manage the garmin-dev container for a Connect IQ project.
#
# Persistent mode (for the bin/ shims; container survives between commands):
#   garmin-dev.sh up [project] [--recreate]   start container (+ display stack)
#   garmin-dev.sh down [project]              stop it
#   garmin-dev.sh status                      list containers, image freshness, sim state
#   garmin-dev.sh shell [project] [--no-display]   interactive shell in it
#   garmin-dev.sh sim [project] <device>      (re)start sim + build + load the app
#
# One-shot mode (ephemeral container, used by test.sh):
#   garmin-dev.sh [project] [bash args]       e.g. ... ../proj -c "make build"
#
# [project] omitted: the nearest ancestor of $PWD containing a manifest.xml.
#
# Env knobs:
#   GARMIN_DEV_HEADLESS=1   force the in-container Xvfb+VNC display stack
#   GARMIN_CREDS_FILE=...   mount a Garmin credentials file for garmin-setup
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
IMAGE=garmin-dev:latest

resolve_project() {
    local arg="${1:-}"
    if [ -n "$arg" ]; then
        PROJECT_DIR="$(cd "$arg" && pwd)"
    else
        local d="$PWD"
        while [ "$d" != / ] && [ ! -f "$d/manifest.xml" ]; do d="$(dirname "$d")"; done
        if [ ! -f "$d/manifest.xml" ]; then
            echo "error: no project given and no manifest.xml in any ancestor of $PWD" >&2
            echo "usage: $0 <command> /path/to/project, or run from inside a project" >&2
            exit 1
        fi
        PROJECT_DIR="$d"
    fi
    local rel="${PROJECT_DIR#"$HOME"/}"
    CONTAINER_NAME="gd-${rel//\//-}"
}

validate_mounts() {
    local missing=()
    for dir in "$HOME/.connectiq" "$PROJECT_DIR"; do
        [ -d "$dir" ] || missing+=("$dir")
    done
    [ -f "$HOME/.connectiq/developer_key.der" ] || missing+=("$HOME/.connectiq/developer_key.der")
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Error: missing paths:"
        printf '  %s\n' "${missing[@]}"
        exit 1
    fi
    # Pre-create rw mount sources as the host user. A missing bind source
    # would be created root-owned by Docker and the SDK download would fail.
    mkdir -p "$HOME/.Garmin" "$HOME/.connect-iq-sdk-manager" "$HOME/.cache/garmin-dev"
}

# Host X display passthrough: the sim window appears on the host desktop and
# the host WM populates _NET_CLIENT_LIST for the screenshot flow. UID match
# makes the host xauth cookie valid in-container. Without a host display
# (or with GARMIN_DEV_HEADLESS=1) the entrypoint starts its own
# Xvfb + openbox + VNC stack; DISPLAY=:99 is set as container env so
# docker exec sessions inherit it, and its ports go to localhost.
display_args() {
    HEADLESS=0
    if [ "${GARMIN_DEV_HEADLESS:-}" != 1 ] && [ -n "${DISPLAY:-}" ] && [ -d /tmp/.X11-unix ]; then
        DISPLAY_ARGS=(
            -e DISPLAY
            -e GDK_BACKEND=x11
            -e LIBGL_ALWAYS_SOFTWARE=1
            -v /tmp/.X11-unix:/tmp/.X11-unix
        )
        if [ -n "${XAUTHORITY:-}" ] && [ -f "$XAUTHORITY" ]; then
            DISPLAY_ARGS+=(-v "$XAUTHORITY:$XAUTHORITY:ro" -e XAUTHORITY)
        fi
    else
        HEADLESS=1
        DISPLAY_ARGS=(
            -e DISPLAY=:99
            -e GDK_BACKEND=x11
            -e LIBGL_ALWAYS_SOFTWARE=1
            -p 127.0.0.1:5900:5900
            -p 127.0.0.1:6080:6080
        )
    fi
}

creds_args() {
    CREDS_ARGS=()
    if [ -n "${GARMIN_CREDS_FILE:-}" ]; then
        if [ ! -f "$GARMIN_CREDS_FILE" ]; then
            echo "Error: GARMIN_CREDS_FILE=$GARMIN_CREDS_FILE not found"
            exit 1
        fi
        CREDS_ARGS=(-v "$(readlink -f "$GARMIN_CREDS_FILE"):/run/secrets/garmin-creds:ro")
    fi
}

# --shm-size: X rendering needs more than Docker's default /dev/shm.
# Default seccomp is fine (verified); the sim segfaults at GTK init only
# when it has no usable DISPLAY.
common_run_args() {
    RUN_ARGS=(
        --name "$CONTAINER_NAME"
        --hostname "$CONTAINER_NAME"
        --label "garmin-dev.project=$PROJECT_DIR"
        --shm-size=512m
        -v "$HOME/.Garmin:$HOME/.Garmin"
        -v "$HOME/.connect-iq-sdk-manager:$HOME/.connect-iq-sdk-manager"
        -v "$HOME/.connectiq:$HOME/.connectiq:ro"
        -v "$HOME/.cache/garmin-dev:$HOME/.cache/garmin-dev"
        "${CREDS_ARGS[@]}"
        "${DISPLAY_ARGS[@]}"
        -v "$PROJECT_DIR:$PROJECT_DIR"
        -w "$PROJECT_DIR"
    )
}

running() {
    docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"
}

require_running() {
    if ! running; then
        echo "error: container $CONTAINER_NAME is not running" >&2
        echo "start it with: $0 up ${PROJECT_DIR}" >&2
        exit 1
    fi
}

warn_if_stale() {
    local proj="${1:-$PROJECT_DIR}" cur latest
    cur="$(docker inspect -f '{{.Image}}' "$CONTAINER_NAME" 2>/dev/null || true)"
    latest="$(docker image inspect -f '{{.Id}}' "$IMAGE" 2>/dev/null || true)"
    if [ -n "$cur" ] && [ -n "$latest" ] && [ "$cur" != "$latest" ]; then
        echo "warning: $CONTAINER_NAME runs an older $IMAGE; recreate with: $0 up $proj --recreate"
    fi
}

cmd_up() {
    local recreate=0 proj=""
    for a in "$@"; do
        case "$a" in
            --recreate) recreate=1 ;;
            *) proj="$a" ;;
        esac
    done
    resolve_project "$proj"
    validate_mounts
    display_args
    creds_args
    common_run_args
    if running; then
        if [ "$recreate" = 1 ]; then
            docker rm -f "$CONTAINER_NAME" >/dev/null
        else
            echo "$CONTAINER_NAME already running (project $PROJECT_DIR)"
            warn_if_stale
            exit 0
        fi
    else
        docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    fi
    docker run -d --rm "${RUN_ARGS[@]}" "$IMAGE" hold >/dev/null
    echo "$CONTAINER_NAME up (project $PROJECT_DIR)"
    if [ "$HEADLESS" = 1 ]; then
        echo "display: headless — noVNC at http://localhost:6080/vnc.html (VNC :5900)"
    else
        echo "display: host X ($DISPLAY)"
    fi
    case ":$PATH:" in
        *":$REPO_DIR/bin:"*) ;;
        *) echo "hint: add the shims to PATH:  export PATH=\"$REPO_DIR/bin:\$PATH\"" ;;
    esac
}

cmd_down() {
    resolve_project "${1:-}"
    if running; then
        docker rm -f "$CONTAINER_NAME" >/dev/null
        echo "$CONTAINER_NAME stopped"
    else
        echo "$CONTAINER_NAME is not running"
    fi
}

cmd_status() {
    local found=0
    while IFS='|' read -r name proj; do
        [ -n "$name" ] || continue
        found=1
        local sim="sim: not running"
        if docker exec "$name" pgrep -f 'bin/simulato[r]' >/dev/null 2>&1; then
            sim="sim: running"
        fi
        # Display mode from the container's configured env, not socket
        # presence: in host-X mode /tmp/.X11-unix is the host's dir and may
        # contain unrelated X99 sockets.
        local disp="host X"
        if docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$name" 2>/dev/null \
                | grep -qx 'DISPLAY=:99'; then
            disp="headless (noVNC http://localhost:6080/vnc.html)"
        fi
        echo "$name  project: $proj  display: $disp  $sim"
        CONTAINER_NAME="$name" warn_if_stale "$proj"
    done < <(docker ps --filter label=garmin-dev.project \
                 --format '{{.Names}}|{{.Label "garmin-dev.project"}}')
    [ "$found" = 1 ] || echo "no garmin-dev containers running"
}

cmd_shell() {
    local proj="" nodisplay=0
    for a in "$@"; do
        case "$a" in
            --no-display) nodisplay=1 ;;
            *) proj="$a" ;;
        esac
    done
    resolve_project "$proj"
    require_running
    warn_if_stale
    local wd="$PROJECT_DIR"
    case "$PWD/" in "$PROJECT_DIR"/*) wd="$PWD" ;; esac
    local env_args=()
    if [ "$nodisplay" = 1 ]; then
        env_args=(-e DISPLAY= -e GARMIN_DEV_NO_DISPLAY=1)
    fi
    exec docker exec -it -w "$wd" "${env_args[@]}" "$CONTAINER_NAME" bash -l
}

# Build + load the project's app into the sim, so "sim" always ends with
# the app visible, never a bare simulator. simrun.sh starts the sim
# if needed and restarts it on a device switch (monkeydo cannot retarget a
# running sim). Settings-override env vars are not forwarded; use the
# shimmed simrun.sh directly for those.
cmd_sim() {
    local proj="" device="" a
    for a in "$@"; do
        if [ -d "$a" ]; then proj="$a"; else device="$a"; fi
    done
    if [ -z "$device" ]; then
        echo "usage: $0 sim [project] <device>" >&2
        exit 1
    fi
    resolve_project "$proj"
    require_running
    warn_if_stale
    docker exec -w "$PROJECT_DIR" "$CONTAINER_NAME" simrun.sh "$device"
}

case "${1:-}" in
    up|down|status|shell|sim)
        cmd="$1"; shift
        "cmd_$cmd" "$@"
        exit 0
        ;;
esac

# One-shot mode (legacy interface): ephemeral container. First arg is the
# project only if it is a directory; otherwise all args go to the container
# and the project comes from the manifest.xml walk.
PROJECT_ARG=""
if [ $# -gt 0 ] && [ -d "$1" ]; then
    PROJECT_ARG="$1"
    shift
fi
resolve_project "$PROJECT_ARG"
validate_mounts
display_args
creds_args
common_run_args

# Interactive TTY only for a plain shell on a terminal; plain -i lets
# test.sh and scripted calls pass bash args like -c "cmd".
TTY_ARGS=(-i)
if [ -t 0 ] && [ $# -eq 0 ]; then
    TTY_ARGS=(-it)
fi

if running; then
    echo "error: $CONTAINER_NAME is already running (persistent mode)." >&2
    echo "use the shims or '$0 shell', or '$0 down' it first." >&2
    exit 1
fi
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

docker run --rm "${TTY_ARGS[@]}" "${RUN_ARGS[@]}" "$IMAGE" "$@"
