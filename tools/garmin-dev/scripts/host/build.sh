#!/bin/bash
# RUNS ON: host
#
# Build the garmin-dev image with the host user's UID/GID/username so the
# container user and home path match the host (see CLAUDE.md invariants).
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

docker build \
    --build-arg USER_ID="$(id -u)" \
    --build-arg GROUP_ID="$(id -g)" \
    --build-arg USERNAME="$(whoami)" \
    -t garmin-dev:latest \
    "$REPO_DIR"
