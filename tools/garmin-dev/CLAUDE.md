Guidance for agents working in this repo. Read this first, then the relevant
file in `agent_docs/`.

## What this is

A Docker dev environment for Garmin Connect IQ watch-face projects. It
exists because the CIQ simulator needs libwebkit2gtk-4.0, which rolling
distros no longer ship. The image pins ubuntu:22.04 (which still carries
it) and bundles the whole toolchain: monkeyc builds, the SDK manager CLI,
in-container SDK download, and the simulator with the screenshot pipeline
(on the host X display, or headless via Xvfb + VNC when none exists). The
image holds only open tooling; the Garmin SDK, device files, signing key,
and credentials are mounted, never baked in.

## Layout

| Path                 | Role                                                       |
|----------------------|------------------------------------------------------------|
| `Dockerfile`         | ubuntu:22.04 image: build-arg user, JDK, Go, SDK mgr CLI   |
| `scripts/host/`      | run on the host: `build.sh`, `garmin-dev.sh`, `test.sh`    |
| `scripts/container/` | baked into the image at /usr/local/bin, run only there     |
| `bin/`               | host shims (`monkeyc`, `monkeydo`, ...): docker exec into the running container; prepend to PATH |
| `agent_docs/`        | deep dives (linked below)                                  |

Container scripts: `entrypoint.sh` (SDK-on-PATH banner, shell),
`garmin-setup` (creds handling + key guard around setup), `setup-connectiq.sh`
(login, EULA, SDK + device download), `verify-connectiq` (toolchain checks),
plus vendored watch-face tooling: `auto-shot.sh`, `screenshot.sh`,
`simrun.sh`, `cut-face.sh`, `gen-settings-doc.py`, `ciq-jungle.sh`. The
vendored copies have documented divergences from the project originals
(locale, window lookup, compare metric, crop fuzz, project root = cwd,
genericized jungle/app/device handling); see
[agent_docs/gotchas.md](agent_docs/gotchas.md) before syncing them.

## Commands

```bash
./scripts/host/build.sh                     # build the image
GARMIN_TEST_PROJECT=/path/to/project ./scripts/host/test.sh [--build]

# Persistent mode (typical use):
./scripts/host/garmin-dev.sh up [project]   # start container once
./scripts/host/garmin-dev.sh sim <device>   # build + load (starts sim if needed)
monkeyc / monkeydo / make build / auto-shot.sh ...   # via bin/ shims on PATH
./scripts/host/garmin-dev.sh shell [--no-display]    # shell in it
./scripts/host/garmin-dev.sh status | down
./scripts/host/garmin-dev.sh up --recreate  # after rebuilding the image

# One-shot mode (ephemeral container; refuses while persistent is up):
./scripts/host/garmin-dev.sh [project] -c "make build"
```

`[project]` omitted anywhere: the nearest ancestor of `$PWD` with a
`manifest.xml`; there is no baked-in project path. `GARMIN_DEV_HEADLESS=1`
forces the in-container Xvfb+VNC display. Shims fail loudly when no
container covers `$PWD`; `GARMIN_DEV_AUTOSTART=1` opts into auto-`up`.
Inside the container: `garmin-setup` (first-run SDK setup, from project
root), `verify-connectiq` (toolchain check).

## Docs

- [agent_docs/architecture.md](agent_docs/architecture.md): the full
  design — image layers, mounts, lifecycle, display modes, shims, setup
  flow, open questions. (The build-out plan was promoted here once
  implemented.)
- [agent_docs/gotchas.md](agent_docs/gotchas.md): non-obvious traps and
  diagnosis case studies. Skim before touching the Dockerfile, launcher,
  entrypoint, or vendored scripts.

## Invariants

- Never bake the Garmin SDK, device files, or credentials into the image or
  any layer. They are mounted or downloaded at runtime into mounted dirs.
- Never generate a Connect IQ developer key in the container. Production
  store ids are bound to the frozen key in host `~/.connectiq/`; mount it
  read-only. `garmin-setup` enforces this.
- The container user must match the host UID/GID and the container home must
  be the same absolute path as the host home. Watch-face project Makefiles
  and scripts hardcode `$HOME/...` paths, and the SDK manager CLI writes
  absolute paths into its config.
- The base image must ship libwebkit2gtk-4.0. ubuntu:22.04 does; 24.04 and
  current Arch do not (4.1 only). Never bump the base without checking.
- Docker only. Podman is explicitly not supported.
- Credentials never go into build-args, image env, or `docker run -e`
  visible state; mount a file read-only.

## Conventions

- Scripts under `scripts/host/` run on the host; scripts under
  `scripts/container/` are baked into the image and run only there. Every
  script states `RUNS ON: host` or `RUNS IN: container` in its header.
- The watch-face project's Makefile resolves `monkeyc`/`monkeydo`/the CLI
  from PATH (`?=` variables) so the `bin/` shims intercept them; keep that
  property when touching either side. Its sim/screenshot make targets check
  local process/port state and only work fully inside the container.
- The container never depends on project-provided scripts; anything it needs
  is vendored into `scripts/container/` and baked into the image.
- Mount everything at its original host path, so configs written
  in-container stay valid on the host.
- Never write container/env state into the mounted project tree (it gets
  committed by accident); host-side state goes under `~/.cache/garmin-dev`.
- No sudo in the image, no `~/.ssh` mount, container runs non-root.
- Never push or commit to git without being asked.

## Documentation Style

- Never name sibling repositories in docs; write "the watch-face project".
- Markdown links for doc references an agent should follow; backticks for
  source paths. Align table columns.
- No AI-isms, no em dashes, no emojis. State the point directly.
- Concise; assume the agent is competent. Add only project-specific facts,
  rules, and the why.
- State each rule on its own line as always/never.
- Mark inferred claims and open questions; don't present a guess as fact.
