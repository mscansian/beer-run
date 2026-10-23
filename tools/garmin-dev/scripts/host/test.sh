#!/bin/bash
# RUNS ON: host
#
# Two tiers (see agent_docs/architecture.md "Testing"):
#   image tests       mount-free, always run
#   integration tests need GARMIN_TEST_PROJECT=/path/to/project, the mounts
#                     and a set-up SDK; auto-skip otherwise.
#                     Pass --build to also run a real `make build`.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

check() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        FAIL=$((FAIL + 1))
    fi
}

run() {
    docker run --rm garmin-dev:latest -c "$1"
}

echo "=== Image tests ==="
check "image exists" docker image inspect garmin-dev:latest

echo "=== Tool tests ==="
check "java is available"      run "java -version"
check "go is available"        run "go version"
check "sdk manager CLI"        run "connect-iq-sdk-manager-cli --help"
check "git is available"       run "git --version"
check "make is available"      run "make --version"
check "openssl is available"   run "openssl version"
check "rg is available"        run "rg --version"
check "fd is available"        run "fd --version"
check "jq is available"        run "jq --version"
check "xmllint is available"   run "xmllint --version"
check "garmin-setup on PATH"   run "which garmin-setup"
check "verify-connectiq baked" run "which verify-connectiq"
check "setup script baked"     run "test -x /usr/local/bin/setup-connectiq.sh"

echo "=== Simulator/screenshot stack ==="
check "libwebkit2gtk-4.0 present" run "ldconfig -p | grep -q libwebkit2gtk-4.0.so.37"
check "simulator deps resolve"    run "ldconfig -p | grep -q libsecret-1.so.0"
check "xvfb is available"         run "which Xvfb"
check "openbox is available"      run "which openbox"
check "xprop is available"        run "which xprop"
check "import (IM) is available"  run "which import"
check "magick is IM7"             run "magick --version | grep -q 'ImageMagick 7'"
check "ss is available"           run "ss --version"
check "auto-shot.sh baked"        run "test -x /usr/local/bin/auto-shot.sh"
check "screenshot.sh baked"       run "test -x /usr/local/bin/screenshot.sh"
check "simrun.sh baked"           run "test -x /usr/local/bin/simrun.sh"

echo "=== Security tests ==="
check "sudo not installed"  run "! which sudo"
check "no ssh keys mounted" run "test ! -d \$HOME/.ssh"
check "running as non-root" run "test \$(id -u) -ne 0"

echo "=== Entrypoint tests ==="
check "no state written into cwd" run "test ! -e .garmin-dev"

echo "=== Integration tests ==="
# Project under test comes from the environment; no baked-in default.
PROJECT=""
if [ -n "${GARMIN_TEST_PROJECT:-}" ]; then
    PROJECT="$(cd "$GARMIN_TEST_PROJECT" && pwd)"
fi
GD_NAME=""
if [ -n "$PROJECT" ]; then
    rel="${PROJECT#"$HOME"/}"
    GD_NAME="gd-${rel//\//-}"
fi
if [ -n "$GD_NAME" ] && docker ps --format '{{.Names}}' | grep -qx "$GD_NAME"; then
    echo "  SKIP: $GD_NAME is already up (persistent mode); 'garmin-dev.sh down' first"
elif [ -n "$PROJECT" ] && [ -d "$HOME/.Garmin/ConnectIQ" ]; then
    irun() {
        "$SCRIPT_DIR/garmin-dev.sh" "$PROJECT" -c "$1" </dev/null
    }
    check "toolchain verifies" irun 'verify-connectiq'
    check "history on host, not in project" irun 'case "$HISTFILE" in "$HOME/.cache/garmin-dev/"*) true;; *) false;; esac && [ ! -e .garmin-dev ]'
    hrun() {
        GARMIN_DEV_HEADLESS=1 "$SCRIPT_DIR/garmin-dev.sh" "$PROJECT" -c "$1" </dev/null
    }
    check "headless Xvfb+WM up" hrun '[ "$DISPLAY" = ":99" ] && xprop -root _NET_SUPPORTING_WM_CHECK | grep -q "window id"'
    check "headless VNC up"     hrun 'pgrep -x x11vnc >/dev/null && curl -s -o /dev/null -w "%{http_code}" http://localhost:6080/vnc.html | grep -q 200'

    echo "=== Persistent mode + shims ==="
    check "up (headless)"        env GARMIN_DEV_HEADLESS=1 "$SCRIPT_DIR/garmin-dev.sh" up "$PROJECT"
    check "container running"    bash -c "docker ps --format '{{.Names}}' | grep -qx '$GD_NAME'"
    check "status shows headless" bash -c "'$SCRIPT_DIR/garmin-dev.sh' status | grep -q headless"
    check "shim monkeyc"         bash -c "cd '$PROJECT' && '$REPO_DIR/bin/monkeyc' --version"
    check "shim CLI"             bash -c "cd '$PROJECT' && '$REPO_DIR/bin/connect-iq-sdk-manager-cli' sdk current-path --bin"
    check "shim fails outside project" bash -c "! (cd /tmp && '$REPO_DIR/bin/monkeyc' --version) 2>/dev/null"
    check "exec shell has SDK on PATH" bash -c "docker exec '$GD_NAME' bash -lc 'which monkeyc' | grep -q Sdks"
    if [ "${1:-}" = "--build" ]; then
        check "make build via shims" bash -c "cd '$PROJECT' && PATH='$REPO_DIR/bin:'\$PATH make build"
        check "output is host-owned" bash -c "test -O \"\$(ls -t '$PROJECT'/bin/*.prg | head -1)\""
    else
        echo "  SKIP: make build via shims (pass --build to run it)"
    fi
    check "down"                 "$SCRIPT_DIR/garmin-dev.sh" down "$PROJECT"
    check "container gone"       bash -c "! docker ps --format '{{.Names}}' | grep -qx '$GD_NAME'"
else
    echo "  SKIP: set GARMIN_TEST_PROJECT=/path/to/project (with manifest.xml + Makefile)"
    echo "        and run garmin-setup once so ~/.Garmin/ConnectIQ is populated"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
