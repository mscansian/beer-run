# Gotchas and findings

Traps identified during the feasibility analysis and build-out (2026-07).
Items marked "unverified" still need an empirical check.

## Contents
- Traps
- Findings

## Traps

- **ubuntu:24.04 and current Arch have no libwebkit2gtk-4.0, only 4.1.**
  The CIQ simulator links `libwebkit2gtk-4.0.so.37` and will not start.
  This is the reason the whole repo exists. Base on ubuntu:22.04 (or Debian
  bookworm); never bump the base image without checking the webkit package.
  This also rules out layering on any 24.04-based local dev image; the
  Dockerfile is standalone by design.
- **A missing bind-mount source is created by Docker as root.** The
  host-UID container process then cannot write into it and the SDK download
  fails on permissions. The launcher pre-creates `~/.Garmin` and
  `~/.connect-iq-sdk-manager` as the host user before `docker run`.
- **Bare `--user UID:GID` breaks `$HOME`-dependent tooling.** With no
  matching passwd entry, `$HOME` is unset and getpwuid fails; every
  hardcoded `$HOME/...` path in project scripts misresolves. Create a real user at build time via build-args, with the
  home path equal to the host home.
- **Home path matters as much as UID.** The SDK manager CLI writes absolute
  paths under `$HOME` into its config; a container home differing from the
  host home makes `sdk current-path` return nonexistent paths even with the
  SDK mounted. Verified working with matching paths.
- **The developer key is chmod 600 and identity-bearing.** Only a
  UID-matched process can read it, and `setup-connectiq.sh` generates a new
  key if none exists, silently changing the signing identity production
  store ids are bound to. `garmin-setup` refuses to run without the mounted
  key, and the `~/.connectiq` mount is read-only.
- **apt in the Dockerfile needs `DEBIAN_FRONTEND=noninteractive` (set as a
  build ARG).** Without it, the first package whose postinst asks a
  debconf question hangs the build forever at an invisible prompt; the
  x11vnc/noVNC dependency chain triggered this via tzdata after two
  rounds of apt layers that happened not to. A "slow" build stuck ~30 min
  is this, not bandwidth: check
  `ps -ef --forest` for a `debconf frontend ... postinst` under the runc
  build step.
- **Editing baked scripts must not invalidate expensive layers.** The
  `COPY scripts/container/...` lines sit last in the Dockerfile, after the
  apt/Go layers. Keep them there; COPY ownership defaults to root
  regardless of the USER directive, so position is free.
- **A sim segfault with `Gtk-CRITICAL _gtk_style_provider_private_...`
  spam means no usable DISPLAY, not seccomp.** Docker's default seccomp
  profile is fine (verified; no WEBKIT_DISABLE_* flags needed either).
  Check DISPLAY/X socket/xauth before touching security options. Keep
  `--shm-size=512m`; the 64 MB default is small for X rendering.
- **Without a UTF-8 locale the screenshot flow captures the wrong
  window.** Device names are non-ASCII ("fēnix"), and under the C locale
  xprop cannot convert the device window's title, so the title lookup
  falls back to the stale blank pre-load window: sim runs and renders
  fine, screenshots come out blank grey. The image sets
  `LANG`/`LC_ALL=C.UTF-8` (glibc's built-in C.utf8, no locales package),
  and `auto-shot.sh`/`screenshot.sh` export `LC_ALL=C.UTF-8`, not `C`.
  Do not revert either.
- **On device load the sim creates a second "CIQ Simulator" window** and
  the initial blank one stays in `_NET_CLIENT_LIST`. `screenshot.sh`
  takes the last title match (newest window), not the first, which would
  capture the blank one.
- **The IM7 AppImage is a Q16-HDRI build: `compare -metric AE` output is
  unusable as a pixel count.** It prints scientific notation with counts
  scaled by 65535 (black-vs-white 240x240 gives 3.77e9, not 57600), which
  a plain `grep '^[0-9]+'` mangles into garbage. `auto-shot.sh` computes
  the changed-pixel fraction via a difference composite instead of
  `compare`.
- **The container GTK theme's window chrome is srgb(246,245,244), ~4% off
  white.** Crop detection with `-fuzz 5%` counts the chrome as device-area
  white, so nothing gets cropped. `screenshot.sh` uses `-fuzz 2%`.
- **docker exec bypasses the entrypoint.** Exec'd commands get only the
  image ENV: no SDK bin on PATH, no HISTFILE, no headless DISPLAY export.
  Three pieces compensate; do not remove any of them:
  `/usr/local/bin/{monkeyc,monkeydo,simulator}` symlinks to `sdk-tool`
  (resolve the SDK per call), `/etc/profile.d/garmin-dev.sh` (recreates the
  env for `bash -l` shells), and `up` setting `DISPLAY=:99` as container
  config env in headless mode (config env is inherited by exec, an
  entrypoint export is not).
- **A timeout-killed `docker run` leaks the container.** Killing the docker
  client (Bash tool timeout, Ctrl-C on a hung run) does not stop the
  container; `--rm` only fires on container exit. One such leak kept an
  Xvfb alive that dropped a stale X99 socket into the host's
  /tmp/.X11-unix (mounted in host-X mode) and confused display detection
  for an hour. Check `docker ps` for unnamed garmin-dev containers after
  killed runs; `status` detects display mode from container config env,
  never from socket files, for this reason.
- **One-shot mode and persistent mode share the container name.** The
  launcher refuses one-shot runs (and test.sh skips integration) while the
  project's persistent container is up; `down` it first.
- **Make targets that wrap host-side sim scripts do not shim.** A target
  that shells out to a script checking local process/port/.SET state
  (`pgrep`, `ss`, /tmp) runs its tools in the container but its checks on
  the host, so the script's world-model breaks. Compile targets shim
  transparently; run sim workflows wholly in-container (shimmed
  `auto-shot.sh`/`simrun.sh`, `garmin-dev.sh sim`, or a shell).
- **monkeydo pushes are unreliable, in two distinct ways, and monkeydo
  itself never tells you.** (a) Into a freshly started sim, a push can die
  silently — port 1234 opens before the sim's shell handler is ready.
  (b) A sim that has been running a few minutes can wedge into a state
  where monkeydo exits 0, prints nothing, and the push is simply ignored.
  Even a successful device switch takes ~10-20 s to appear (full device
  reload). Consequences: never trust monkeydo's exit status or the
  "loaded" handoff; verify on screen. `simrun.sh` polls this
  container's sim window (matched by `_NET_WM_PID` — the X server is
  shared, so titles alone are ambiguous) for the target device's
  `displayName` (from the device's `compiler.json`) and, on timeout,
  restarts the sim and re-pushes (a fresh sim + push is the reliable
  path). A same-device reload cannot be verified this way (the title does
  not change) and is pushed blind. Each push also leaves a monkeydo java
  attached for the app's lifetime; the sim scripts kill leftovers
  before each push so they don't accumulate.
- **The `displayName` title check is untested against long names.** Some
  device files name several editions in one string, with slashes. Whether
  the sim puts the whole string in the window title is unverified (open
  question). If such a device times out in `simrun.sh` while the app is
  visibly rendered, check the title with `xprop` before blaming the push
  path.
- **Device files outrun the installed SDK.** The SDK manager's device
  download always delivers the current device file, whose `api.debug.xml`
  carries the newest API surface regardless of which SDK is installed. A
  device file fetched 2026-10-20 exposed SDK 9.3 symbols while the
  container ran SDK 9.2.0. A build error on a new API is an SDK gap, not a
  device file gap (inferred from a symbol diff, not from a failed build).
- **The container shares the host X server, including its window list.**
  A simulator running on the host (or another container) is
  indistinguishable from the container's own in the title lookup. Don't
  run two at once when screenshotting.
- **The screenshot script needs a window manager** (headless mode). It locates
  the sim window via `xprop -root _NET_CLIENT_LIST`; bare Xvfb has no WM,
  the property is empty, and the lookup fails. Run openbox under Xvfb in
  fallback mode. On the host-X path the host WM provides this for free.
- **Garmin login is the only potential hard blocker.** Headless
  username/password SSO can hit MFA/CAPTCHA and Garmin changes the flow
  periodically. Mitigation: interactive first login (`-it`), token
  persisted in the mounted state dirs, non-interactive afterward. Never
  pass creds via build-args or `-e` (visible in `docker history`/
  `docker inspect`); the launcher mounts a file read-only.
- **Do not mount `/tmp/com.garmin.connectiq` from the host.** The sim's
  `.SET` files live there and project scripts may delete them; container-local `/tmp` is correct and isolation from host sim
  state is a feature.
- **The sim scripts find the app from the current directory.**
  `auto-shot.sh`/`simrun.sh` derive the jungle/app name via
  `resolve_jungle` in `ciq-jungle.sh` (single `*.jungle`, or the base
  jungle whose stem prefixes all others, e.g. `foo.jungle` among
  `foo-dev.jungle`/`foo-beta.jungle`; `JUNGLE=<file>` overrides, anything
  ambiguous errors), require the DEVICE argument, and default output to
  `/tmp/ciq-sim.png`.

## Findings

### Why the SDK is downloaded in-container instead of pre-mounted

- **Symptom:** Original design mounted a host-populated SDK read-only.
- **Diagnosis:** That leaves the env non-self-bootstrapping and keeps the
  fragile download step on the fragile host.
- **Fix:** The image bakes `setup-connectiq.sh` and runs the download
  itself (via `garmin-setup`) with mounted creds, writing to mounted
  `~/.Garmin` so it persists. The SDK download is auth-gated behind a
  Garmin account and EULA, so it must never be baked into a layer; with
  the mount design the image stays clean of Garmin-proprietary bits.
- **Takeaway:** The rw mounts for `~/.Garmin` and
  `~/.connect-iq-sdk-manager` are part of the contract, not an
  optimization. See the invariants in [../CLAUDE.md](../CLAUDE.md).

### The blank-screenshot diagnosis chain

- **Symptom:** Sim window appeared on the host desktop with menu bar but a
  blank grey device area; `monkeydo` silent; screenshots blank; render
  never "confirmed".
- **Diagnosis:** The app had loaded and rendered all along, in a second
  window. `/proc/<sim>/task` showed the full device runtime (TVM, GPS,
  ANT threads); `xwininfo -root -tree` showed the second window with title
  "(failure in conversion from UTF8_STRING to ANSI_X3.4-1968)" — the
  missing-locale trap above. Every earlier hypothesis (seccomp, WebKit
  sandbox, D-Bus, GLX, missing repaint) was wrong; the pipeline was fine.
- **Fix:** UTF-8 locale in the image + last-match window lookup, plus the
  AE-metric and crop-fuzz fixes uncovered right after.
- **Takeaway:** When the sim "loads nothing", check for a second X window
  and the sim's thread list before touching security or graphics knobs.
  Verified result: in-container renders are dimensionally identical to
  host-era gallery images.

### First verification silently reused the host's SDK through the mounts

- **Symptom:** Integration tests passed on the first run, before any
  in-container `garmin-setup`.
- **Diagnosis:** The host already had a downloaded SDK and token in
  `~/.Garmin`; the mounts made them visible in-container, which is exactly
  the intended reuse behavior.
- **Takeaway:** A from-scratch `garmin-setup` (empty `~/.Garmin`) is still
  unexercised; treat it as untested until run on a clean machine (open
  question in [architecture.md](architecture.md)).
