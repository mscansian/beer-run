# Architecture: the Docker Connect IQ dev environment

Promoted from the build-out plan (all phases implemented and verified,
2026-07). Non-obvious traps live in [gotchas.md](gotchas.md); read it
before changing the Dockerfile, launcher, entrypoint, or vendored scripts.

## Why this exists

The CIQ simulator links libwebkit2gtk-4.0.so.37; rolling distros ship only
the 4.1 ABI, so the sim cannot run on the host. The container pins
ubuntu:22.04 (which still carries 4.0) and packages the whole dev loop:
monkeyc builds, SDK download, interactive simulator, and the screenshot
pipeline. The image holds only open tooling; everything Garmin-proprietary
(SDK, device files, key, credentials) is mounted or downloaded at runtime
into mounted dirs (see the invariants in [../CLAUDE.md](../CLAUDE.md)).

## Image

`Dockerfile`, ubuntu:22.04. Layer order (cheap-to-change last):

1. apt base: JDK (headless), make, git, openssl, xml/search tools.
   `DEBIAN_FRONTEND=noninteractive` as a build ARG; `TZ`, `LANG`/`LC_ALL`
   (C.UTF-8) as env — all three are trap-derived, see gotchas.
2. Go toolchain from upstream tarball (jammy's apt golang is too old for
   the SDK manager CLI).
3. Simulator/GUI stack: `libwebkit2gtk-4.0-37`, `libgtk-3-0`, the sim's
   other direct deps (from `objdump -p`: libsecret, libusb, libsm,
   libxxf86vm, libxkbcommon), Xvfb + openbox + x11vnc + noVNC/websockify,
   x11-utils, ImageMagick 6 (apt, provides `import`), iproute2, software
   GL, fonts.
4. ImageMagick 7 AppImage (extracted; `magick` is not in jammy's apt) from
   the latest ImageMagick GitHub release; x86_64 only.
5. Build-arg user matching host UID/GID/username, so the container home
   equals the host home path.
6. SDK manager CLI via `go install` into `$HOME/go/bin` (an image layer;
   `$HOME` itself is never mounted).
7. `scripts/container/*` into /usr/local/bin (+ `sdk-tool` symlinks and
   `/etc/profile.d/garmin-dev.sh`); last so script edits stay cheap.

Rejected alternatives: layering on another local dev image (24.04 base, no
webkit 4.0); podman (Docker is a hard constraint); pre-mounting a
host-downloaded SDK (superseded by in-container download so the env
self-bootstraps); Claude Code in the image (not needed).

## Mounts (launcher pre-creates rw sources, validates the rest)

| Host path                   | Mode | Purpose                                             |
|-----------------------------|------|-----------------------------------------------------|
| `~/.Garmin`                 | rw   | SDK + device bins, written by in-container download |
| `~/.connect-iq-sdk-manager` | rw   | CLI config and login token (login is one-time)      |
| `~/.connectiq`              | ro   | frozen developer key; ro blocks accidental keygen   |
| creds file                  | ro   | `GARMIN_USERNAME`/`GARMIN_PASSWORD`, first run only |
| `~/.cache/garmin-dev`       | rw   | bash history + sim/monkeydo logs, keyed by container name |
| project dir                 | rw   | at original host path                               |

Everything mounts at its original host path, so absolute paths written by
the CLI in-container stay valid on the host and vice versa.

## Container lifecycle

Two modes, one image, shared mount/display plumbing in `garmin-dev.sh`:

- **Persistent** (typical): `up` runs the container detached with the
  `hold` entrypoint argument (display bootstrap, then sleep) and a
  `garmin-dev.project=<dir>` label. All work arrives via `docker exec`:
  the `bin/` shims, `shell`, `sim`, `status`. `down` removes it;
  `up --recreate` swaps it after an image rebuild (status warns when the
  running image is stale).
- **One-shot**: `garmin-dev.sh [project] [bash args]` runs an ephemeral
  `--rm` container through the full entrypoint (used by test.sh). Refuses
  to run while the project's persistent container holds the name.

## Display modes

Decided at container start, not per-exec:

- **Host X** (default when `DISPLAY` is set): passes `DISPLAY`, the
  `/tmp/.X11-unix` socket dir, and the xauth cookie at its host path; the
  sim appears on the desktop and the host WM populates `_NET_CLIENT_LIST`
  for the screenshot lookup. UID match makes the host cookie valid.
- **Headless** (no host DISPLAY, or `GARMIN_DEV_HEADLESS=1`): the
  entrypoint starts Xvfb :99 + openbox + x11vnc + noVNC; the launcher sets
  `DISPLAY=:99` as container config env (so exec'd commands inherit it)
  and publishes 5900/6080 on localhost. Interactive use via
  `http://localhost:6080/vnc.html` (no password, localhost-only).

Verified facts: Docker's default seccomp is fine, no WEBKIT_DISABLE_*
flags needed, rendering is llvmpipe software GL, `--shm-size=512m`. Both
modes produce pixel-identical screenshot dimensions.

## Shims and the exec environment

Host shims in `bin/` (symlinks to `garmin-shim`): `monkeyc`, `monkeydo`,
`simulator`, `connect-iq-sdk-manager-cli`, `auto-shot.sh`,
`screenshot.sh`, `simrun.sh`, `cut-face.sh`, `gen-settings-doc.py`.
Each resolves the running container whose project label covers `$PWD` and
execs the same tool name there with the same cwd/argv. No container: fail
loudly (`GARMIN_DEV_AUTOSTART=1` opts into auto-`up`, project root found
via nearest `manifest.xml`).

`docker exec` bypasses the entrypoint, so three pieces recreate its
environment (all load-bearing, see gotchas): the `sdk-tool` wrappers
(`/usr/local/bin/{monkeyc,monkeydo,simulator}` resolve the active SDK per
call), `/etc/profile.d/garmin-dev.sh` (SDK-first PATH, headless DISPLAY,
HISTFILE for `bash -l` shells), and headless `DISPLAY=:99`
living in container config env.

Bash history and the sim/monkeydo logs (`<container>.sim.log`,
`<container>.monkeydo.log`, written by the vendored `simrun.sh`/
`auto-shot.sh`) live on the host in the mounted `~/.cache/garmin-dev/`,
keyed by container name — readable from the host, surviving the container.
Never write state into the mounted project tree: project-local dotdirs get
committed by accident.

Contract with the watch-face project: its Makefile resolves `monkeyc`/
`monkeydo`/`simulator`/the CLI from PATH (`?=` variables), so host
`make build`/`package` transparently go through the shims. Its
sim/screenshot make targets check local process/port state and only work
fully inside the container.

## SDK setup flow

`garmin-setup` (in-container, from the project root) guards the
developer-key invariant (refuses to run without the mounted key, because
the setup script would otherwise generate a new signing identity), loads
creds from the mounted file if present, then runs the baked
`setup-connectiq.sh`: login, agreement accept, `sdk set`, device download
from the project manifest (`--include-fonts`; devices without fonts
segfault the sim). The login token persists in the mounted state dirs, so
login is one-time; later downloads are non-interactive.

## Screenshot pipeline

The vendored `auto-shot.sh` (build, relaunch sim, wait for the face to
render by frame-diffing, capture) and `screenshot.sh` (window-id capture
by title, chrome crop, seeded-floodfill transparency) are copies of the
watch-face project's scripts with documented divergences (locale,
last-match window lookup, compare metric, crop fuzz, project root = cwd,
and genericization: jungle/app derived from the cwd via `ciq-jungle.sh`,
DEVICE required, neutral output defaults); gotchas.md lists each with its
reason. Sync deliberately when the originals change.

## Testing

`scripts/host/test.sh`, three groups: image tests (mount-free: tools,
baked scripts, security posture, entrypoint); integration tests (mounted:
`verify-connectiq`, headless display stack, VNC); persistent-mode tests
(up, shims, status, transparent `make build` with `--build`, down).
Auto-skips when the SDK isn't set up or the persistent container is
already running. Sim rendering is verified by the screenshot pipeline
itself; interactive Simulation-menu workflows are verified by hand.

## Out of scope

- MTP sideload to a physical watch (`make install`): USB, host-only.
- The online VS Code App Settings editor: use the offline properties.xml
  path in-container.
- Publishing the image anywhere.

## Open questions

- A from-scratch `garmin-setup` (empty `~/.Garmin`) is untested: MFA or
  CAPTCHA may force the first login to be interactive. Test before
  relying on the creds file on a clean machine.
- Token lifetime (`token.json` in `~/.Garmin/ConnectIQ` plus
  `~/.connect-iq-sdk-manager` state): re-login frequency unknown.
- Interactive Simulation-menu workflows (GPS, HR, weather) have not been
  exercised in-container; the window is a normal desktop/VNC window, so
  they are expected to work.
