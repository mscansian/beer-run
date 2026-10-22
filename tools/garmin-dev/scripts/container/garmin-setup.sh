#!/bin/bash
# RUNS IN: container (baked as /usr/local/bin/garmin-setup)
#
# Run the Connect IQ SDK setup (login, EULA, SDK + device download) using the
# setup-connectiq.sh baked into the image. This wrapper handles credentials
# and guards the developer-key invariant.
#
# Credentials: a file mounted at /run/secrets/garmin-creds containing
#   GARMIN_USERNAME=...
#   GARMIN_PASSWORD=...
# (launcher mounts it when GARMIN_CREDS_FILE is set). Without it, login is
# interactive; the token persists in the mounted ~/.connect-iq-sdk-manager,
# so login is one-time either way.
#
# Usage: garmin-setup [SDK_VERSION] [path/to/manifest.xml]
# Run from the project root so the default manifest.xml is found.
set -euo pipefail

SETUP="/usr/local/bin/setup-connectiq.sh"

# Never create a key in the container: the store id is bound to the frozen
# host key. setup-connectiq.sh generates one only if absent, so require it.
if [ ! -f "$HOME/.connectiq/developer_key.der" ]; then
    echo "Error: $HOME/.connectiq/developer_key.der is missing." >&2
    echo "Refusing to run setup (it would generate a new signing key)." >&2
    echo "Mount the existing host key via the launcher." >&2
    exit 1
fi

CREDS="/run/secrets/garmin-creds"
if [ -f "$CREDS" ]; then
    echo "Using credentials from $CREDS"
    set -a
    # shellcheck source=/dev/null
    . "$CREDS"
    set +a
else
    echo "No creds file at $CREDS — Garmin login will be interactive."
fi

exec "$SETUP" "$@"
