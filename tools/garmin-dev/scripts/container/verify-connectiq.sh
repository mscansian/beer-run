#!/bin/bash
# RUNS IN: container (baked as /usr/local/bin/verify-connectiq)
#
# Verify the Connect IQ toolchain end to end: SDK manager CLI, active SDK,
# device files, developer key, monkeyc. Project-independent; run anywhere.
# Exits nonzero if any check fails.
set -uo pipefail

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

CLI="$HOME/go/bin/connect-iq-sdk-manager-cli"
check "SDK manager CLI present"   test -x "$CLI"

SDK_BIN="$("$CLI" sdk current-path --bin 2>/dev/null || true)"
check "an SDK is set"             test -n "$SDK_BIN"
check "SDK bin dir exists"        test -d "$SDK_BIN"
check "monkeyc runs"              "$SDK_BIN/monkeyc" --version
check "java available"            java -version
check "device files downloaded"   test -n "$(ls -A "$HOME/.Garmin/ConnectIQ/Devices" 2>/dev/null)"
check "developer key readable"    test -r "$HOME/.connectiq/developer_key.der"

echo "verify-connectiq: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
