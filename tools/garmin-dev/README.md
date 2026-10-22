# garmin-dev

Docker-based development environment for Garmin Connect IQ watch-face
projects. It packages the brittle parts of the CIQ toolchain (the
simulator's webkit2gtk 4.0 dependency, Java, the SDK manager CLI) into a
pinned image so builds and simulator runs survive host distro upgrades.

## What it provides

- Compile and package watch faces with `monkeyc` inside the container
- Download the Connect IQ SDK and device files in-container using mounted
  Garmin credentials; everything downloaded persists to mounted host dirs
- Run the CIQ simulator interactively on the host X display and take
  screenshots (`auto-shot.sh`, `screenshot.sh` baked into the image)
- Headless fallback: without a host display (or with
  `GARMIN_DEV_HEADLESS=1`) the container runs its own Xvfb + openbox and
  serves the sim over VNC (5900) and noVNC
  (`http://localhost:6080/vnc.html`), localhost-only, no password

The image contains only open tooling. The Garmin SDK, device files, signing
key, and credentials are always mounted from the host, never baked in — so
the built image must never be pushed to a registry, and there is no reason
to: anyone can rebuild it locally with their own Garmin account.

## Layout

Scripts are split by where they run:

| Dir                  | Runs      | Contents                                        |
|----------------------|-----------|-------------------------------------------------|
| `scripts/host/`      | host      | `build.sh`, `garmin-dev.sh` (launcher), `test.sh` |
| `scripts/container/` | container | baked into the image: entrypoint, `garmin-setup`, `setup-connectiq.sh`, `verify-connectiq` |

## Usage

```bash
./scripts/host/build.sh                  # build the image (once)
GARMIN_TEST_PROJECT=/path/to/project ./scripts/host/test.sh [--build]
                                         # verify (project needed for the
                                         # integration tier; skipped without)
```

Typical flow — start the environment once, then use native-feeling shims.
Commands take a project directory argument, or default to the nearest
ancestor of the current directory containing a `manifest.xml` (below,
`gd` stands for `/path/to/garmin-dev/scripts/host/garmin-dev.sh` and the
current directory is the project root):

```bash
export PATH="/path/to/garmin-dev/bin:$PATH"   # once, in your shell profile

gd up                                    # start the container
gd sim fenix843mm                        # build + load the face (starts sim if needed)
make build                               # transparently compiles in-container
monkeydo bin/app.prg fenix843mm          # loads into the container's sim
auto-shot.sh -t fenix843mm out.png       # screenshot pipeline
gd shell                                 # interactive shell (--no-display to opt out)
gd down                                  # stop
```

The shims (`bin/monkeyc`, `monkeydo`, `simulator`,
`connect-iq-sdk-manager-cli`, `auto-shot.sh`, ...) run their command inside
the container that covers the current directory, same cwd and arguments.
They fail with a clear message if no container is up
(`GARMIN_DEV_AUTOSTART=1` opts into auto-start). After rebuilding the
image, `garmin-dev.sh up --recreate` swaps the running container.

First-run SDK setup, inside the container (`garmin-dev.sh shell`):

```bash
garmin-setup       # Garmin login, EULA, SDK + device download
verify-connectiq   # check the toolchain end to end
```

## Status

Implemented and verified: headless builds, in-container SDK download,
simulator + screenshots (host display or fully headless over VNC), the
persistent container with host shims. Design details in
`agent_docs/architecture.md`.

## Requirements

- Docker
- A Garmin account (first SDK download requires login)
- An existing Connect IQ developer key on the host (`~/.connectiq/`)
